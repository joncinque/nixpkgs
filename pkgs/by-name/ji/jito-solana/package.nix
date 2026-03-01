{
  fetchFromGitHub,
  lib,
  makeRustPlatform,
  nix-update-script,
  pkgs,
  stdenv,

  installShellFiles,
  makeWrapper,
  openssl,
  pkg-config,
  protobuf,
  solana-libpoh-simd,
  udev,

  # Build flags
  buildDCOUBins ? true,
  buildDeprecatedBins ? true,
  buildDevBins ? true,
  buildEndUserBins ? true,
  buildPlatformTools ? false, # No work has been done to support this
  buildValidatorBins ? true,
}:

let
  mkBuildscriptFlags =
    {
      buildDCOUBins ? false,
      buildDeprecatedBins ? false,
      buildDevBins ? false,
      buildEndUserBins ? false,
      buildPlatformTools ? false,
      buildValidatorBins ? false,
    }:
    with lib;
    optional (!buildDCOUBins) "--no-build-dcou-bins"
    ++ optional (!buildDeprecatedBins) "--no-build-deprecated-bins"
    ++ optional (!buildDevBins) "--no-build-dev-bins"
    ++ optional (!buildEndUserBins) "--no-build-end-user-bins"
    ++ optional (!buildPlatformTools) "--no-build-platform-tools"
    ++ optional (!buildValidatorBins) "--no-build-validator-bins";

  regularBuildscriptFlags = mkBuildscriptFlags {
    inherit
      buildDeprecatedBins
      buildDevBins
      buildEndUserBins
      buildPlatformTools
      buildValidatorBins
      ;
  };
  dcouBuildscriptFlags = mkBuildscriptFlags { inherit buildDCOUBins; };

  buildRegularBinaries =
    buildDeprecatedBins || buildDevBins || buildEndUserBins || buildPlatformTools || buildValidatorBins;
in
stdenv.mkDerivation (
  finalAttrs:
  let
    # Unfortunately Agave requires to be built using a specific rust version, specified in the toolchain file
    rustToolchain =
      let
        rust-overlay-src = fetchFromGitHub {
          owner = "oxalica";
          repo = "rust-overlay";
          rev = "db61f666aea93b28f644861fbddd37f235cc5983";

          hash = "sha256-jTof2+ir9UPmv4lWksYO6WbaXCC0nsDExrB9KZj7Dz4=";
        };

        rust-overlay = lib.fix (final: pkgs // (import rust-overlay-src) final pkgs);
      in
      rust-overlay.rust-bin.fromRustupToolchainFile "${finalAttrs.src}/rust-toolchain.toml";

    rustPlatform = makeRustPlatform {
      cargo = rustToolchain;
      rustc = rustToolchain;
    };
  in
  {
    pname = "jito-solana";
    version = "3.1.9";

    src = fetchFromGitHub {
      owner = "jito-foundation";
      repo = "jito-solana";
      rev = "v${finalAttrs.version}-jito";
      hash = "sha256-nSqmnfcbLPiKuM6lNi/dFXq3SG1RQlTikFPHrkFSDeI=";
      fetchSubmodules = true;
    };

    patches = [ ./modularise-buildscript.patch ];

    nativeBuildInputs = [
      installShellFiles
      makeWrapper
      pkg-config
      protobuf

      rustPlatform.cargoSetupHook
      rustPlatform.bindgenHook
      rustToolchain
    ];

    buildInputs = [
      openssl
      udev
    ];

    env = {
      NO_RUSTUP_OVERRIDE = 1; # Agave uses a custom cargo wrapper which ensures the correct version, this disables it
      OPENSSL_NO_VENDOR = 1; # Use system openssl
      RUSTFLAGS = "-C target-cpu=native"; # Target building CPU
      PROTOC="${protobuf}/bin/protoc";
      PROTOC_INCLUDE="${protobuf}/include";
    };

    postPatch = ''
      patchShebangs .
    '';
    cargoVendorDir = "cargo-vendor-dir";

    regularVendorDir = rustPlatform.importCargoLock {
      lockFile = "${finalAttrs.src}/Cargo.lock";

      outputHashes = {
        "crossbeam-epoch-0.9.5" = "sha256-Jf0RarsgJiXiZ+ddy0vp4jQ59J9m0k3sgXhWhCdhgws=";
      };
    };

    dcouVendorDir = rustPlatform.importCargoLock {
      lockFile = "${finalAttrs.src}/dev-bins/Cargo.lock";
    };

    buildPhase = lib.concatStringsSep "\n" (
      lib.optional buildRegularBinaries ''
        rm -rf cargo-vendor-dir
        cp -Lr --reflink=auto -- "${finalAttrs.regularVendorDir}" cargo-vendor-dir
        chmod -R +644 -- cargo-vendor-dir

        cp $src/.cargo/config.toml .cargo/config.toml
        cat cargo-vendor-dir/.cargo/config.toml >> .cargo/config.toml

        ./scripts/cargo-install-all.sh ${lib.concatStringsSep " " regularBuildscriptFlags} --no-perf-libs --no-spl-token $out
      ''
      ++ lib.optional buildDCOUBins ''
        rm -rf cargo-vendor-dir
        cp -Lr --reflink=auto -- "${finalAttrs.dcouVendorDir}" cargo-vendor-dir
        chmod -R +644 -- cargo-vendor-dir

        cp $src/.cargo/config.toml .cargo/config.toml
        cat cargo-vendor-dir/.cargo/config.toml >> .cargo/config.toml

        ./scripts/cargo-install-all.sh ${lib.concatStringsSep " " dcouBuildscriptFlags} --no-perf-libs --no-spl-token $out
      ''
    );

    # Already performed by the script from the agave repo
    installPhase = "";

    postInstall =
      ''
        rmdir --ignore-fail-on-non-empty $out/bin/deps
      ''
      + lib.optionalString (buildEndUserBins && stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
        installShellCompletion --cmd solana \
          --bash <($out/bin/solana completion --shell bash) \
          --fish <($out/bin/solana completion --shell fish) \
          --zsh <($out/bin/solana completion --shell zsh)
      ''
      + lib.optionalString buildValidatorBins ''
        wrapProgram $out/bin/agave-validator \
          --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ solana-libpoh-simd ]}"
      '';

    doCheck = false;

    passthru = {
      inherit rustToolchain;

      updateScript = nix-update-script {
        extraArgs = [
          "--version-regex"
          "^v([0-9.]+)$"
        ];
      };
    };

    meta = {
      description = "Jito Foundation MEV Solana Client";
      homepage = "https://github.com/jito-foundation/jito-solana";
      changelog = "https://github.com/jito-foundation/jito-solana/blob/v${finalAttrs.version}/CHANGELOG.md";
      license = lib.licenses.asl20;
      sourceProvenance = with lib.sourceTypes; [
        fromSource
      ];
      maintainers = with lib.maintainers; [
        joncinque
      ];
    };
  }
)
