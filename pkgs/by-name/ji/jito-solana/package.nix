{
  fetchFromGitHub,
  lib,
  solana-agave,
  ...
}:
solana-agave.overrideAttrs (
  finalAttrs: oldAttrs: {
    pname = "jito-solana";
    version = "4.1.0-rc.0";

    src = fetchFromGitHub {
      owner = "jito-foundation";
      repo = "jito-solana";
      rev = "v${finalAttrs.version}-jito";
      fetchSubmodules = true;

      hash = "sha256-kqKDYx3QqzBlDEN56v1mtDI4bQcKAceYSHTw+V6qMpE=";
    };

    passthru = lib.attrsets.recursiveUpdate oldAttrs.passthru { solana.jitoSupport = true; };
  }
)
