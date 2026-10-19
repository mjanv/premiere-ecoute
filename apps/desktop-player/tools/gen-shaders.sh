#!/usr/bin/env bash
# Pre-compile GPUI's HLSL shaders when cross-compiling (the upstream build script only runs fxc on a Windows host).
# Uses the Windows d3dcompiler_47.dll through tools/hlslc (run via WSL interop).
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
src=$root/vendor/gpui-pre-windows/src
exe=$root/tools/hlslc/target/x86_64-pc-windows-msvc/release/hlslc.exe
tmp=$(mktemp -d /mnt/c/Users/lanfe/AppData/Local/Temp/shaders.XXXX)
trap 'rm -rf "$tmp"' EXIT

inline() { sed -e "/#include \"alpha_correction.hlsl\"/{r $src/alpha_correction.hlsl" -e 'd}' "$1"; }
inline "$src/shaders.hlsl" > "$tmp/shaders.hlsl"
inline "$src/color_text_raster.hlsl" > "$tmp/emoji.hlsl"

out=$root/vendor/gpui-pre-windows/shaders_bytes.rs
: > "$out"
compile() { # file module vs_name
  local f; f=$(wslpath -w "$tmp/$1")
  local up; up=$(echo "$2" | tr a-z A-Z)
  "$exe" "$f" "${2}_vertex" vs_4_1 "${up}_VERTEX_BYTES" >> "$out"
  "$exe" "$f" "${2}_fragment" ps_4_1 "${up}_FRAGMENT_BYTES" >> "$out"
}
for m in quad shadow path_rasterization path_sprite underline monochrome_sprite subpixel_sprite polychrome_sprite; do
  compile shaders.hlsl "$m"
done
compile emoji.hlsl emoji_rasterization
echo "wrote $out"
