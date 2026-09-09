{
  fetchFromGitHub,
  lib,
  solana-agave,
  ...
}:
solana-agave.overrideAttrs (
  finalAttrs: oldAttrs: {
    pname = "jito-solana";
    version = "4.2.2";

    src = fetchFromGitHub {
      owner = "jito-foundation";
      repo = "jito-solana";
      rev = "v${finalAttrs.version}-jito";
      fetchSubmodules = true;

      hash = "sha256-fjBJtzemodhAWZgPwvfN3EHB9hr4eUOJ0ynKLnwfFnw=";
    };

    passthru = lib.attrsets.recursiveUpdate oldAttrs.passthru { solana.jitoSupport = true; };
  }
)
