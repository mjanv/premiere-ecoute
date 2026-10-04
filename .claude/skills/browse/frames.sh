#!/usr/bin/env bash
# frames.sh <video.webm> [seconds-between-frames=2]  -> <video>-frames/f-NN.png (read them to "watch" the video)
set -euo pipefail
v="$1"; every="${2:-2}"; d="${v%.webm}-frames"; mkdir -p "$d"
ffmpeg -v error -y -i "$v" -vf "fps=1/$every,scale=640:-1" "$d/f-%02d.png"
echo "$d"; ls "$d"
