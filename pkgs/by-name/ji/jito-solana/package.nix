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
      rev = "7037b4f425e655b8f973ee8ebea9a4de1a85b208";
      fetchSubmodules = true;

      hash = "sha256-8gLbQFOj9z0oAcltaZd91TbE2nPm8FIM4kRFHQxZU04=";
    };

    passthru = lib.attrsets.recursiveUpdate oldAttrs.passthru { solana.jitoSupport = true; };
  }
)
