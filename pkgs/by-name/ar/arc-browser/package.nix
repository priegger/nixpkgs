{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
  writeShellApplication,
  curl,
  common-updater-scripts,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "arc-browser";
  version = "1.101.0-64746";

  src = fetchurl {
    url = "https://releases.arc.net/release/Arc-${finalAttrs.version}.dmg";
    hash = "sha256-u391hQB+Fqw21cu9GQglOkPHie+8uK8FTxSLWLAH0eA=";
  };

  nativeBuildInputs = [ undmg ];

  sourceRoot = "Arc.app";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications/Arc.app"
    cp -R . "$out/Applications/Arc.app"

    runHook postInstall
  '';

  dontFixup = true;

  passthru.updateScript = lib.getExe (writeShellApplication {
    name = "arc-browser-update-script";
    runtimeInputs = [
      curl
      common-updater-scripts
    ];
    text = ''
      redirect_url="$(curl -s -L -f "https://releases.arc.net/release/Arc-latest.dmg" -o /dev/null -w '%{url_effective}')"
      # The url scheme is: https://releases.arc.net/release/Arc-1.23.4-56789.dmg
      # We strip everything before 'Arc-' and after '.dmg'
      version="''${redirect_url##*/Arc-}"
      version="''${version%.dmg}"
      update-source-version arc-browser "$version" --file=./pkgs/by-name/ar/arc-browser/package.nix
    '';
  });

  meta = {
    description = "Arc from The Browser Company";
    homepage = "https://arc.net/";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ donteatoreo ];
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
