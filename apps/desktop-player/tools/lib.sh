# Shared by the tools/*.sh scripts that reach Windows through WSL interop. Source it, do not run it.

# Windows directory the exes are copied into, as a WSL path. WIN_DIR overrides it (default: the Windows user's profile).
win_dir() {
  echo "${WIN_DIR:-/mnt/c/Users/$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')}"
}

# Windows temp directory, as a WSL path.
win_temp() {
  wslpath "$(cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')"
}
