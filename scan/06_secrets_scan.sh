#!/bin/bash
# ============================================================
#  PHASE 6 — Secret / Key Discovery in JS files
#  Variables: BBP_BASE, BBP_SECRETFINDER
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -z "$BBP_BASE" ] && source "$SCRIPT_DIR/setup.env"

JS_LIST="${BBP_BASE}/recon/urls/js_files.txt"
OUT="${BBP_BASE}/scan/secrets"
SECRETFINDER="${BBP_SECRETFINDER:-${HOME}/tools/SecretFinder/SecretFinder.py}"
mkdir -p "${OUT}/js_downloaded"

if [ ! -f "$JS_LIST" ] || [ ! -s "$JS_LIST" ]; then
    echo "[WARN] js_files.txt vide ou introuvable. Lancer 02_url_collection.sh d'abord."
fi

# --- Download JS files ---
echo "[*] Downloading JS files..."
while IFS= read -r url; do
    SAFE=$(echo "$url" | md5sum | cut -d' ' -f1)
    curl -sk --max-time "${BBP_TIMEOUT:-10}" "$url" -o "${OUT}/js_downloaded/${SAFE}.js" 2>/dev/null
done < "$JS_LIST"
echo "[+] Downloaded $(ls "${OUT}/js_downloaded/" | wc -l) JS files"

# --- SecretFinder ---
if [ -f "$SECRETFINDER" ]; then
    echo "[*] Running SecretFinder on downloaded files..."
    for jsfile in "${OUT}/js_downloaded/"*.js; do
        python3 "$SECRETFINDER" -i "$jsfile" -o cli 2>/dev/null >> "${OUT}/secretfinder_results.txt"
    done

    echo "[*] Running SecretFinder on live URLs..."
    while IFS= read -r url; do
        python3 "$SECRETFINDER" -i "$url" -o cli 2>/dev/null >> "${OUT}/secretfinder_live.txt"
    done < "$JS_LIST"
else
    echo "[WARN] SecretFinder introuvable: $SECRETFINDER"
    echo "       Installer: git clone https://github.com/m4ll0k/SecretFinder ~/tools/SecretFinder"
fi

# --- Grep manuel pour patterns courants ---
echo "[*] Grepping for common secret patterns..."
grep -rh \
    -E "(api_key|apikey|api-key|secret|token|password|passwd|pwd|private_key|access_key|AWS_|authorization|client_secret|bearer)['\"]?\s*[:=]\s*['\"][^'\"]{8,}" \
    "${OUT}/js_downloaded/" \
    > "${OUT}/grep_secrets.txt" 2>/dev/null

# --- Patterns AWS spécifiques ---
grep -rh -E "AKIA[0-9A-Z]{16}" "${OUT}/js_downloaded/" >> "${OUT}/grep_secrets.txt" 2>/dev/null

echo "[+] Secret scan results in ${OUT}/"
echo "    SecretFinder offline:  $(wc -l < "${OUT}/secretfinder_results.txt" 2>/dev/null || echo 0) findings"
echo "    SecretFinder live:     $(wc -l < "${OUT}/secretfinder_live.txt" 2>/dev/null || echo 0) findings"
echo "    Grep patterns:         $(wc -l < "${OUT}/grep_secrets.txt" 2>/dev/null || echo 0) findings"
echo ""
echo "[!] RAPPEL: La plupart sont des faux positifs — vérifier si les clés sont actives avant de reporter"
