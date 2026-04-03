#!/bin/bash
# ============================================================
#  PHASE 5 — Directory / Endpoint Bruteforce
#  Variables: BBP_BASE, BBP_SECLISTS, BBP_FEROX_TARGET, BBP_FFUF_TARGET
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -z "$BBP_BASE" ] && source "$SCRIPT_DIR/setup.env"

OUT="${BBP_BASE}/scan/dirsearch"
WL="${BBP_SECLISTS:-${HOME}/SecLists}"
PRIORITY="${BBP_PRIORITY_TARGETS_FILE:-${BBP_BASE}/config/priority_targets.txt}"
DIRSEARCH="${BBP_DIRSEARCH:-dirsearch}"
mkdir -p "$OUT"

if [ ! -d "$WL" ]; then
    echo "[ERROR] SecLists introuvable: $WL"
    echo "        Installer: git clone https://github.com/danielmiessler/SecLists ~/SecLists"
    exit 1
fi

if [ ! -f "$PRIORITY" ]; then
    echo "[ERROR] priority_targets.txt introuvable: $PRIORITY"
    exit 1
fi

# --- Dirsearch / ffuf sur chaque cible prioritaire ---
while IFS= read -r TARGET; do
    [[ "$TARGET" =~ ^#.*$ || -z "$TARGET" ]] && continue
    SAFE=$(echo "$TARGET" | sed 's/[^a-zA-Z0-9]/_/g')
    echo "[*] Scanning: $TARGET"

    # Utiliser dirsearch si disponible, sinon ffuf
    if command -v dirsearch &>/dev/null || [ -f "$DIRSEARCH" ]; then
        CMD="dirsearch"
        [ -f "$DIRSEARCH" ] && CMD="python3 $DIRSEARCH"
        $CMD -u "$TARGET" \
            -w "${WL}/Discovery/Web-Content/api/api-endpoints.txt" \
            -e php,asp,aspx,json,xml,js,txt,bak,zip \
            --format json \
            -o "${OUT}/dirsearch_${SAFE}.json" \
            --timeout="${BBP_TIMEOUT:-10}" \
            --threads="${BBP_THREADS_MED:-30}" \
            -q 2>/dev/null
    else
        echo "[*] dirsearch indisponible, utilisation de ffuf..."
        # API endpoints
        ffuf -u "${TARGET}/FUZZ" \
            -w "${WL}/Discovery/Web-Content/api/api-endpoints.txt" \
            -mc 200,201,204,301,302,401,403,405 \
            -t "${BBP_THREADS_MED:-30}" \
            -timeout "${BBP_TIMEOUT:-10}" \
            -o "${OUT}/ffuf_${SAFE}_api.json" \
            -of json \
            -s 2>/dev/null
        # Common paths
        ffuf -u "${TARGET}/FUZZ" \
            -w "${WL}/Discovery/Web-Content/common.txt" \
            -mc 200,201,204,301,302,401,403,405 \
            -t "${BBP_THREADS_MED:-30}" \
            -timeout "${BBP_TIMEOUT:-10}" \
            -o "${OUT}/ffuf_${SAFE}_common.json" \
            -of json \
            -s 2>/dev/null
    fi
    echo "[+] Done: $TARGET"
done < "$PRIORITY"

# --- Feroxbuster récursif sur la cible API principale ---
if [ -n "$BBP_FEROX_TARGET" ] && command -v feroxbuster &>/dev/null; then
    echo "[*] feroxbuster on ${BBP_FEROX_TARGET}..."
    feroxbuster \
        --url "$BBP_FEROX_TARGET" \
        --wordlist "${WL}/Discovery/Web-Content/api/api-endpoints-res.txt" \
        --extensions json,xml \
        --depth 3 \
        --threads "${BBP_THREADS_MED:-30}" \
        --timeout "${BBP_TIMEOUT:-10}" \
        --status-codes 200,201,204,301,302,401,403,405 \
        --output "${OUT}/ferox_$(echo "$BBP_FEROX_TARGET" | sed 's/[^a-zA-Z0-9]/_/g').txt" \
        --quiet
fi

# --- ffuf sur la cible auth ---
if [ -n "$BBP_FFUF_TARGET" ]; then
    echo "[*] ffuf on ${BBP_FFUF_TARGET}..."
    ffuf -u "${BBP_FFUF_TARGET}/FUZZ" \
        -w "${WL}/Discovery/Web-Content/common.txt" \
        -mc 200,201,204,301,302,401,403 \
        -t "${BBP_THREADS_MED:-30}" \
        -timeout "${BBP_TIMEOUT:-10}" \
        -o "${OUT}/ffuf_$(echo "$BBP_FFUF_TARGET" | sed 's/[^a-zA-Z0-9]/_/g').json" \
        -of json \
        -s 2>/dev/null
fi

echo "[+] Dir scan results in ${OUT}/"
