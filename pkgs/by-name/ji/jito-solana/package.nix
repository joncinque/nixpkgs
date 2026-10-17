{
  fetchFromGitHub,
  lib,
  solana-agave,
  ...
}:
solana-agave.overrideAttrs (
  finalAttrs: oldAttrs: {
    pname = "jito-solana";
    version = "4.3.2";

    src = fetchFromGitHub {
      owner = "jito-foundation";
      repo = "jito-solana";
      rev = "v${finalAttrs.version}-jito";
      fetchSubmodules = true;

      hash = "sha256-R4Z23MYisazEP6+uQ+WlUrJS6803oNE3GIyLhor87x0=";
    };

    passthru = lib.attrsets.recursiveUpdate oldAttrs.passthru { solana.jitoSupport = true; };
  }
)
