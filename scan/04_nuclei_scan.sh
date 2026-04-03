#!/bin/bash
# ============================================================
#  PHASE 4 — Nuclei Vulnerability Scan
#  Variables: BBP_BASE, BBP_NUCLEI_TEMPLATES, BBP_RATE_LIMIT_NUCLEI
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -z "$BBP_BASE" ] && source "$SCRIPT_DIR/setup.env"

SUBS="${BBP_BASE}/recon/subdomains/live_urls.txt"
PRIORITY="${BBP_PRIORITY_TARGETS_FILE:-${BBP_BASE}/config/priority_targets.txt}"
OUT="${BBP_BASE}/scan/nuclei"
TEMPLATES="${BBP_NUCLEI_TEMPLATES:-${HOME}/nuclei-templates}"
mkdir -p "$OUT"

if [ ! -f "$SUBS" ]; then
    echo "[ERROR] live_urls.txt introuvable. Lancer 01_subdomain_enum.sh d'abord."
    exit 1
fi

echo "[*] Updating nuclei templates..."
nuclei -update-templates -silent 2>/dev/null

# --- Critical + High sur tous les hosts ---
echo "[*] Running nuclei critical/high scan on $(wc -l < "$SUBS") hosts..."
nuclei -l "$SUBS" \
    -severity critical,high \
    -t "$TEMPLATES/" \
    -rate-limit "${BBP_RATE_LIMIT_NUCLEI:-50}" \
    -timeout "${BBP_TIMEOUT:-10}" \
    -retries 2 \
    -o "${OUT}/critical_high.txt" \
    -stats

# --- Medium sur les cibles prioritaires ---
if [ -f "$PRIORITY" ]; then
    echo "[*] Running nuclei medium scan on priority targets..."
    nuclei -l "$PRIORITY" \
        -severity medium \
        -t "$TEMPLATES/" \
        -rate-limit "${BBP_THREADS_MED:-30}" \
        -o "${OUT}/medium_priority.txt"
fi

# --- Exposures, misconfigs, tokens ---
echo "[*] Running targeted template scans (exposures/misconfigs)..."
nuclei -l "$SUBS" \
    -t "${TEMPLATES}/exposures/" \
    -t "${TEMPLATES}/misconfiguration/" \
    -rate-limit "${BBP_THREADS_MED:-30}" \
    -o "${OUT}/exposures_misconfigs.txt" 2>/dev/null

# --- CORS ---
echo "[*] Running CORS scan..."
nuclei -l "$SUBS" \
    -t "${TEMPLATES}/misconfiguration/cors-misconfiguration.yaml" \
    -o "${OUT}/cors.txt" 2>/dev/null

echo "[+] Nuclei results in ${OUT}/"
echo "    Critical/High:       $(wc -l < "${OUT}/critical_high.txt" 2>/dev/null || echo 0)"
echo "    Medium (priority):   $(wc -l < "${OUT}/medium_priority.txt" 2>/dev/null || echo 0)"
echo "    Exposures/Misconfig: $(wc -l < "${OUT}/exposures_misconfigs.txt" 2>/dev/null || echo 0)"
echo ""
echo "[!] RAPPEL: Toujours confirmer manuellement avant de reporter — nuclei génère des faux positifs"
