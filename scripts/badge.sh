#!/usr/bin/env bash
# Writes a flat shields-style SVG badge: scripts/badge.sh <label> <message> <color> <out.svg>
set -euo pipefail
label=$1 message=$2 color=$3 out=$4
lw=$(( (${#label} * 66 + 120 + 5) / 10 ))
mw=$(( (${#message} * 66 + 120 + 5) / 10 ))
w=$((lw + mw))
cat > "$out" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="20" role="img" aria-label="$label: $message">
<linearGradient id="s" x2="0" y2="100%"><stop offset="0" stop-color="#bbb" stop-opacity=".1"/><stop offset="1" stop-opacity=".1"/></linearGradient>
<clipPath id="r"><rect width="$w" height="20" rx="3" fill="#fff"/></clipPath>
<g clip-path="url(#r)"><rect width="$lw" height="20" fill="#555"/><rect x="$lw" width="$mw" height="20" fill="$color"/><rect width="$w" height="20" fill="url(#s)"/></g>
<g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" font-size="11">
<text x="$((lw / 2))" y="14">$label</text><text x="$((lw + mw / 2))" y="14">$message</text></g></svg>
SVG
