{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  ghostscript,
  netpbm,
  perl,
}:
# TODO: withTex

stdenv.mkDerivation rec {
  pname = "latex2html";
  version = "2025";

  src = fetchFromGitHub {
    owner = "latex2html";
    repo = "latex2html";
    rev = "v${version}";
    sha256 = "sha256-xylIU2GY/1t9mA8zJzEjHwAIlvVxZmUAUdQ/IXEy+Wg=";
  };

  buildInputs = [
    ghostscript
    netpbm
    perl
  ];

  nativeBuildInputs = [ makeWrapper ];

  configurePhase = ''
    runHook preConfigure

    ./configure \
      --prefix="$out" \
      --without-mktexlsr \
      --with-texpath=$out/share/texmf/tex/latex/html

    runHook postConfigure
  '';

  postInstall = ''
    for p in $out/bin/{latex2html,pstoimg}; do \
      wrapProgram $p --add-flags '--tmp="''${TMPDIR:-/tmp}"'
    done
  '';

  meta = with lib; {
    description = "LaTeX-to-HTML translator";
    longDescription = ''
      A Perl program that translates LaTeX into HTML (HyperText Markup
      Language), optionally creating separate HTML files corresponding to each
      unit (e.g., section) of the document. LaTeX2HTML proceeds by interpreting
      LaTeX (to the best of its abilities). It contains definitions from a wide
      variety of classes and packages, and users may add further definitions by
      writing Perl scripts that provide information about class/package
      commands.
    '';

    homepage = "https://www.ctan.org/pkg/latex2html";

    license = licenses.gpl2Only;
    platforms = with platforms; linux ++ darwin;
    maintainers = with maintainers; [ yurrriq ];
  };
}
