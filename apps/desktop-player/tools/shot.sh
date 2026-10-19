#!/usr/bin/env bash
# Launch a built exe on Windows, wait, capture its window to a PNG, kill it.
# usage: tools/shot.sh <exe-on-windows C:\path> <out.png> [wait-seconds] [PLAYER_UI_PREVIEW value]
set -euo pipefail
exe=$1; out=$2; wait=${3:-4}; preview=${4:-}
win_out=$(wslpath -w "$out")
powershell.exe -NoProfile -Command "
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System; using System.Runtime.InteropServices;
public class W { [DllImport(\"user32.dll\")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport(\"user32.dll\")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport(\"user32.dll\")] public static extern bool SetProcessDPIAware();
  [DllImport(\"user32.dll\")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport(\"user32.dll\")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [StructLayout(LayoutKind.Sequential)] public struct R { public int L,T,Rr,B; } }
'@
[void][W]::SetProcessDPIAware()
\$env:PLAYER_UI_PREVIEW = '$preview'
\$p = Start-Process -FilePath '$exe' -PassThru
Start-Sleep -Seconds $wait
\$p.Refresh()
[void][W]::ShowWindow(\$p.MainWindowHandle, 9)
[void][W]::SetWindowPos(\$p.MainWindowHandle, [IntPtr](-1), 0, 0, 0, 0, 3)
[void][W]::SetForegroundWindow(\$p.MainWindowHandle)
Start-Sleep -Milliseconds 500
\$r = New-Object W+R
[void][W]::GetWindowRect(\$p.MainWindowHandle, [ref]\$r)
\$w = \$r.Rr - \$r.L; \$h = \$r.B - \$r.T
if (\$w -le 0) { Write-Host 'no window'; Stop-Process \$p -Force; exit 1 }
\$bmp = New-Object System.Drawing.Bitmap \$w, \$h
\$g = [System.Drawing.Graphics]::FromImage(\$bmp)
\$g.CopyFromScreen(\$r.L, \$r.T, 0, 0, \$bmp.Size)
\$bmp.Save('$win_out')
Stop-Process \$p -Force
Write-Host \"saved \${w}x\${h}\"
"
