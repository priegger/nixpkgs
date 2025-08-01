{
  lib,
  buildPackages,
  callPackage,
  pkgs,
  pkgsLinux,

  diffoscopeMinimal,
  runCommand,
  runCommandWith,
  stdenv,
  stdenvNoCC,
  replaceVars,
  testers,
}:
# Documentation is in doc/build-helpers/testers.chapter.md
{
  # See https://nixos.org/manual/nixpkgs/unstable/#tester-lycheeLinkCheck
  # or doc/build-helpers/testers.chapter.md
  inherit (callPackage ./lychee.nix { }) lycheeLinkCheck;

  # See https://nixos.org/manual/nixpkgs/unstable/#tester-testBuildFailure
  # or doc/build-helpers/testers.chapter.md
  testBuildFailure =
    drv:
    drv.overrideAttrs (orig: {
      builder = buildPackages.bash;
      args = [
        (replaceVars ./expect-failure.sh {
          coreutils = buildPackages.coreutils;
          vars = lib.toShellVars {
            outputNames = (orig.outputs or [ "out" ]);
          };
        })
        orig.realBuilder or stdenv.shell
      ]
      ++ orig.args or [
        "-e"
        ../../stdenv/generic/source-stdenv.sh
        (orig.builder or ../../stdenv/generic/default-builder.sh)
      ];
    });

  # See https://nixos.org/manual/nixpkgs/unstable/#tester-testBuildFailurePrime
  # or doc/build-helpers/testers.chapter.md
  testBuildFailure' = callPackage ./testBuildFailurePrime { };

  # See https://nixos.org/manual/nixpkgs/unstable/#tester-testEqualDerivation
  # or doc/build-helpers/testers.chapter.md
  testEqualDerivation = callPackage ./test-equal-derivation.nix { };

  # See https://nixos.org/manual/nixpkgs/unstable/#tester-testEqualContents
  # or doc/build-helpers/testers.chapter.md
  testEqualContents =
    {
      assertion,
      actual,
      expected,
    }:
    runCommand "equal-contents-${lib.strings.toLower assertion}"
      {
        inherit assertion actual expected;
        nativeBuildInputs = [ diffoscopeMinimal ];
      }
      ''
        echo "Checking:"
        printf '%s\n' "$assertion"
        if ! diffoscope --no-progress --text-color=always --exclude-directory-metadata=no -- "$actual" "$expected"
        then
          echo
          echo 'Contents must be equal, but were not!'
          echo
          echo "+: expected,   at $expected"
          echo "-: unexpected, at $actual"
          false
        else
          echo "expected $expected and actual $actual match."
          echo OK
          touch -- "$out"
        fi
      '';

  # See https://nixos.org/manual/nixpkgs/unstable/#tester-testEqualArrayOrMap
  # or doc/build-helpers/testers.chapter.md
  testEqualArrayOrMap = callPackage ./testEqualArrayOrMap { };

  # See https://nixos.org/manual/nixpkgs/unstable/#tester-testVersion
  # or doc/build-helpers/testers.chapter.md
  testVersion =
    {
      package,
      command ? "${package.meta.mainProgram or package.pname or package.name} --version",
      version ? package.version,
    }:
    runCommand "${package.name}-test-version"
      {
        nativeBuildInputs = [ package ];
        meta.timeout = 60;
      }
      ''
        if output=$(${command} 2>&1 | sed -e 's|${builtins.storeDir}/[^/ ]*/|{{storeDir}}/|g'); then
          if grep -Fw -- "${version}" - <<< "$output"; then
            touch $out
          else
            echo "Version string '${version}' not found!" >&2
            echo "The output was:" >&2
            echo "$output" >&2
            exit 1
          fi
        else
          echo -n ${lib.escapeShellArg command} >&2
          echo " returned a non-zero exit code." >&2
          echo "$output" >&2
          exit 1
        fi
      '';

  # See https://nixos.org/manual/nixpkgs/unstable/#tester-invalidateFetcherByDrvHash
  # or doc/build-helpers/testers.chapter.md
  invalidateFetcherByDrvHash =
    f: args:
    let
      drvPath = (f args).drvPath;
      # It's safe to discard the context, because we don't access the path.
      salt = builtins.unsafeDiscardStringContext (lib.substring 0 12 (baseNameOf drvPath));
      # New derivation incorporating the original drv hash in the name
      salted = f (args // { name = "${args.name or "source"}-salted-${salt}"; });
      # Make sure we did change the derivation. If the fetcher ignores `name`,
      # `invalidateFetcherByDrvHash` doesn't work.
      checked =
        if salted.drvPath == drvPath then
          throw "invalidateFetcherByDrvHash: Adding the derivation hash to the fixed-output derivation name had no effect. Make sure the fetcher's name argument ends up in the derivation name. Otherwise, the fetcher will not be re-run when its implementation changes. This is important for testing."
        else
          salted;
    in
    checked;

  # See https://nixos.org/manual/nixpkgs/unstable/#tester-runCommand
  runCommand = testers.invalidateFetcherByDrvHash (
    {
      hash ? pkgs.emptyFile.outputHash,
      name,
      script,
      stdenv ? stdenvNoCC,
      ...
    }@args:

    runCommandWith {
      inherit name stdenv;

      derivationArgs = {
        outputHash = hash;
        outputHashMode = "recursive";
      }
      // lib.removeAttrs args [
        "hash"
        "name"
        "script"
        "stdenv"
      ];
    } script
  );

  # See https://nixos.org/manual/nixpkgs/unstable/#tester-runNixOSTest
  # or doc/build-helpers/testers.chapter.md
  runNixOSTest =
    let
      nixos = import ../../../nixos/lib {
        inherit lib;
      };
    in
    testModule:
    nixos.runTest {
      _file = "pkgs.runNixOSTest implementation";
      imports = [
        (lib.setDefaultModuleLocation "the argument that was passed to pkgs.runNixOSTest" testModule)
      ];
      hostPkgs = pkgs;
      node.pkgs = pkgsLinux;
    };

  # See https://nixos.org/manual/nixpkgs/unstable/#tester-invalidateFetcherByDrvHash
  # or doc/build-helpers/testers.chapter.md
  nixosTest =
    let
      /*
        The nixos/lib/testing-python.nix module, preapplied with arguments that
        make sense for this evaluation of Nixpkgs.
      */
      nixosTesting = (
        import ../../../nixos/lib/testing-python.nix {
          inherit (stdenv.hostPlatform) system;
          inherit pkgs;
          extraConfigurations = [
            (
              { lib, ... }:
              {
                config.nixpkgs.pkgs = lib.mkDefault pkgsLinux;
              }
            )
          ];
        }
      );
    in
    test:
    let
      loadedTest = if builtins.typeOf test == "path" then import test else test;
      calledTest = lib.toFunction loadedTest pkgs;
    in
    nixosTesting.simpleTest calledTest;

  hasPkgConfigModule =
    { moduleName, ... }@args:
    lib.warn
      "testers.hasPkgConfigModule has been deprecated in favor of testers.hasPkgConfigModules. It accepts a list of strings via the moduleNames argument instead of a single moduleName."
      (
        testers.hasPkgConfigModules (
          builtins.removeAttrs args [ "moduleName" ]
          // {
            moduleNames = [ moduleName ];
          }
        )
      );
  hasPkgConfigModules = callPackage ./hasPkgConfigModules/tester.nix { };

  hasCmakeConfigModules = callPackage ./hasCmakeConfigModules/tester.nix { };

  testMetaPkgConfig = callPackage ./testMetaPkgConfig/tester.nix { };

  shellcheck = callPackage ./shellcheck/tester.nix { };

  shfmt = callPackage ./shfmt { };
}
