# Distribution

`tools/package.sh` builds the release exe and produces `dist/premiere-ecoute-player-<version>-setup.exe` and `-portable.zip`.

- **Static CRT**: `.cargo/config.toml` sets `+crt-static` for the MSVC target, so the exe has no `VCRUNTIME140.dll` dependency and runs on a clean Windows.
- **Icon and version info**: `build.rs` embeds `assets/app.rc` (with `assets/icon.ico`) via `embed-resource`/`llvm-rc`. Regenerate the icon with `python3 tools/gen-icon.py`. Bump the version in `Cargo.toml` and in `assets/app.rc`.
- **Installer**: `installer/installer.nsi` (NSIS, built on Linux with `makensis`). Per-user (`%LOCALAPPDATA%\Programs\premiere-ecoute-player`), Start menu shortcut, uninstall entry. Uninstalling keeps `%APPDATA%\premiere-ecoute-player` and the saved sign-in.
- **Release**: push a `v*` tag, the same one as the Stream Deck release, and `.github/workflows/release-desktop-player.yml` runs `tools/package.sh` on Ubuntu and attaches the installer and the zip to that release. The files are named after the version in `Cargo.toml`, not after the tag, and the job fails if `Cargo.toml` and `assets/app.rc` disagree. The release body is left to the Stream Deck workflow.
- **Release profile**: thin LTO and stripped symbols. Never `panic = "abort"`.
- Not done: code signing (SmartScreen warns on unsigned downloads), auto-update, start with Windows.
