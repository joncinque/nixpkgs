{
  fetchFromGitHub,
  lib,
  solana-agave,
  ...
}:
solana-agave.overrideAttrs (
  finalAttrs: oldAttrs: {
    pname = "jito-solana";
    version = "4.2.0-rc.1";

    src = fetchFromGitHub {
      owner = "jito-foundation";
      repo = "jito-solana";
      rev = "v${finalAttrs.version}-jito";
      fetchSubmodules = true;

      hash = "sha256-4B3t/+kSa0Z2LJqkAG4uGyVW3zHV+PbP6zkGW5s+N24=";
    };

    passthru = lib.attrsets.recursiveUpdate oldAttrs.passthru { solana.jitoSupport = true; };
  }
)
