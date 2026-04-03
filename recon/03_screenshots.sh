#!/bin/bash
# ============================================================
#  PHASE 3 — Screenshots des hosts vivants (review visuelle)
#  Variables: BBP_BASE, BBP_THREADS_LOW
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -z "$BBP_BASE" ] && source "$SCRIPT_DIR/setup.env"

SUBS="${BBP_BASE}/recon/subdomains/live_urls.txt"
OUT="${BBP_BASE}/recon/screenshots"
mkdir -p "$OUT"

echo "[*] Taking screenshots with httpx..."
httpx -l "$SUBS" \
    -screenshot \
    -srd "$OUT" \
    -threads "${BBP_THREADS_LOW:-20}" \
    -timeout 15 \
    -silent

echo "[+] Screenshots saved in ${OUT}/"
