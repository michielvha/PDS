# Changelog

## 2026-06-01

### Changed

- **Set-AzureCLI**: Now disables the Windows Web Account Manager (WAM) broker via `az config set core.enable_broker_on_windows=false`, reverting `az login` to the browser-based authentication flow and avoiding the "User cancelled the Accounts Control Operation" account picker.

## 2026-02-16

### Fixed

- **APT repository GPG key format**: Changed `gpg --armor --export` to `gpg --export` (binary format) in the `build-apt-package.yml` pipeline. The `.gpg` file extension requires binary OpenPGP format per `apt-secure(8)`, but the key was being exported in ASCII-armored format, causing `NO_PUBKEY` errors when clients ran `apt update`.
