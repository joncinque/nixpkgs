{
  fetchFromGitHub,
  lib,
  solana-agave,
  ...
}:
solana-agave.overrideAttrs (
  finalAttrs: oldAttrs: {
    pname = "jito-solana";
    version = "4.1.0-rc.1";

    src = fetchFromGitHub {
      owner = "jito-foundation";
      repo = "jito-solana";
      rev = "v${finalAttrs.version}-jito";
      fetchSubmodules = true;

      hash = "sha256-fBBmyL0LHL4UPMFjVIf77Oy5AAfcfo7akhYUbhWFo8Q=";
    };

    passthru = lib.attrsets.recursiveUpdate oldAttrs.passthru { solana.jitoSupport = true; };
  }
)
