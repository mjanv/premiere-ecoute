#!/usr/bin/env bash
# Launch the release exe on Windows without Spotify (PLAYER_UI_PREVIEW=idle), check that it stays up and opens a window, close it.
# usage: tools/smoke.sh [exe]   (default: the release exe built by cargo xwin)
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/lib.sh
exe=${1:-target/x86_64-pc-windows-msvc/release/premiere-ecoute-player.exe}
wait=${SMOKE_WAIT:-6}

taskkill.exe /F /IM pep-smoke.exe >/dev/null 2>&1 || true
for _ in $(seq 20); do cp "$exe" "$(win_dir)/pep-smoke.exe" 2>/dev/null && break; sleep 0.5; done
win_exe=$(wslpath -w "$(win_dir)/pep-smoke.exe")

powershell.exe -NoProfile -Command "
Add-Type @'
using System; using System.Runtime.InteropServices;
public class W { [DllImport(\"user32.dll\")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [StructLayout(LayoutKind.Sequential)] public struct R { public int L,T,Rr,B; } }
'@
\$env:PLAYER_UI_PREVIEW = 'idle'
\$p = Start-Process -FilePath '$win_exe' -PassThru
Start-Sleep -Seconds $wait
\$p.Refresh()
if (\$p.HasExited) { Write-Host \"smoke: exited early with code \$(\$p.ExitCode)\"; exit 1 }
\$r = New-Object W+R
[void][W]::GetWindowRect(\$p.MainWindowHandle, [ref]\$r)
\$w = \$r.Rr - \$r.L; \$h = \$r.B - \$r.T
Stop-Process \$p -Force
if (\$w -le 0 -or \$h -le 0) { Write-Host 'smoke: no window'; exit 1 }
Write-Host \"smoke: ok, window \${w}x\${h}\"
"
