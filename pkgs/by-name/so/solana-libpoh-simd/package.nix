{
  fetchFromGitHub,
  lib,
  stdenv,

  ispc,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "solana-libpoh-simd";
  version = "0.19.3";

  src =
    (fetchFromGitHub {
      owner = "anza-xyz";
      repo = "solana-perf-libs";
      rev = "233c4457fd8d425da99cb3db46b2be8eb8b98997";
      hash = "sha256-mBS+iVdj0ePZ5DDcCeOkQpsvvQYcCka0LblZbBezs0s=";
    })
    + /src/poh-simd;

  nativeBuildInputs = [ ispc ];

  installPhase = ''
    mkdir -p $out/lib

    cp -r libs/* $out/lib
  '';

  meta = {
    description = "C and CUDA libraries to enhance Solana";
    homepage = "https://github.com/anza-xyz/solana-perf-libs";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
    ];
    maintainers = with lib.maintainers; [
      joncinque
      Managarmrr
    ];
  };
})
