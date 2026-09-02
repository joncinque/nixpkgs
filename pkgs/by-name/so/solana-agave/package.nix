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
  rocksdb,
  udev,
  jq,

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
          rev = "860d7c835ab91bfc8972b67092f5f2db8e9390a0";
          hash = "sha256-BTFrmyh0oaVDsvA9NNw0YpbbeppTwU0t70iVx672Ew8=";
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
    pname = "solana-agave";
    version = "4.3.0-beta.3";

    src = fetchFromGitHub {
      owner = "anza-xyz";
      repo = "agave";
      rev = "v${finalAttrs.version}";

      hash = "sha256-fZuSnZ7anLDCLYi5279dLWD+zUDXgWrhJvO12qzyqLg=";
    };

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
    ] ++ lib.optionals finalAttrs.passthru.solana.jitoSupport [ jq protobuf ];

    env = {
      NO_RUSTUP_OVERRIDE = 1; # Agave uses a custom cargo wrapper which ensures the correct version, this disables it
      OPENSSL_NO_VENDOR = 1; # Use system openssl
      #ROCKSDB_LIB_DIR = "${rocksdb}/lib"; # Use vendored rocksdb
      RUSTFLAGS = "-C target-cpu=native"; # Target building CPU
    };

    postPatch = ''
      patchShebangs .
    '';
    cargoVendorDir = "cargo-vendor-dir";

    regularVendorDir = rustPlatform.importCargoLock {
      lockFile = "${finalAttrs.src}/Cargo.lock";

      outputHashes = {
        "crossbeam-epoch-0.9.20" = "sha256-VsfKBHzxilKABOqvf7vWY51ndABjTH56c+WxpGaKAr8=";
        "librocksdb-sys-0.17.3+10.4.2" = "sha256-9Wt0b6UFXDzdZWPsbwQEcPGXuCZWJ10bEJD/MGxNq/0=";
      };
    };

    dcouVendorDir = rustPlatform.importCargoLock {
      lockFile = "${finalAttrs.src}/dev-bins/Cargo.lock";

      outputHashes = {
        "librocksdb-sys-0.17.3+10.4.2" = "sha256-9Wt0b6UFXDzdZWPsbwQEcPGXuCZWJ10bEJD/MGxNq/0=";
      };
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
      '';

    doCheck = false;

    passthru = {
      inherit rustToolchain;

      solana = {
        deploymentFlavour = "agave";
        jitoSupport = false;
      };
      updateScript = nix-update-script { };
    };

    meta = {
      description = "Web-Scale Blockchain for fast, secure, scalable, decentralized apps and marketplaces.";
      homepage = "https://github.com/anza-xyz/agave";
      changelog = "https://github.com/anza-xyz/agave/blob/v${finalAttrs.version}/CHANGELOG.md";
      license = lib.licenses.asl20;
      sourceProvenance = with lib.sourceTypes; [
        fromSource
      ];
      maintainers = with lib.maintainers; [
        joncinque
        Managarmrr
      ];
    };
  }
)
