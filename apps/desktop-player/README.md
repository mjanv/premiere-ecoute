# Premiere Ecoute Player

A Windows desktop app that shows and controls the Spotify desktop app running on the same PC, without the Spotify Web API: cover, title, progress, play, pause, previous, next, volume, and a live waveform of what Spotify plays. It can optionally link to a Première Écoute backend, which then sees what plays and can send commands.

Written in Rust with GPUI (through `gpui-kit`), developed in WSL2 and cross-compiled to a native Windows executable.

```
cargo xwin build --target x86_64-pc-windows-msvc --release
```

To hand it to someone, run `tools/package.sh`. It writes `dist/premiere-ecoute-player-<version>-setup.exe` (per-user installer: no admin rights, Start menu entry, uninstaller) and `dist/premiere-ecoute-player-<version>-portable.zip` (just the exe). The exe is self-contained: static C runtime, no Visual C++ Redistributable needed. The installer needs `makensis` (`apt install nsis`). Windows SmartScreen warns about unsigned downloads until the exe is code-signed.

For development, copy `target/x86_64-pc-windows-msvc/release/premiere-ecoute-player.exe` to Windows and run it. Everything about building, testing and the layout of the code is in [AGENTS.md](AGENTS.md).

| Document | What it covers |
|---|---|
| [AGENTS.md](AGENTS.md) | Build and test commands, conventions, how the code is laid out |
| [docs/architecture.md](docs/architecture.md) | How it works: threads, Windows APIs, the backend link, the waveform, the build |
| [docs/distribution.md](docs/distribution.md) | Installer, portable zip, icon, versioning, what is not done (signing, auto-update) |
| [docs/ui.md](docs/ui.md) | The design: palette from the cover, type, ruler, waveform, footer |
| [docs/adr/0001-remote-control-via-phoenix-channels.md](docs/adr/0001-remote-control-via-phoenix-channels.md) | Why and how the player links to the backend |
| [docs/refactoring.md](docs/refactoring.md) | What to tidy next, with priorities |

To try the backend link, start the player, click "Connect to server" in the footer, and sign in.
