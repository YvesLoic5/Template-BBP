#!/bin/bash
# ============================================================
#  PHASE 7 — CORS Misconfiguration Testing
#  Variables: BBP_BASE, BBP_CORS_ORIGINS
#  Un CORS est reportable seulement si credentials: true
#  ET que l'endpoint retourne des données sensibles
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -z "$BBP_BASE" ] && source "$SCRIPT_DIR/setup.env"

SUBS="${BBP_BASE}/recon/subdomains/live_urls.txt"
OUT="${BBP_BASE}/scan/nuclei/cors_detail.txt"
mkdir -p "${BBP_BASE}/scan/nuclei"

# Utiliser les origines de la config ou des défauts
if [ -n "$BBP_CORS_ORIGINS" ]; then
    IFS=' ' read -ra ORIGINS <<< "$BBP_CORS_ORIGINS"
else
    ORIGINS=(
        "https://evil.com"
        "https://TARGET.evil.com"
        "https://evil-TARGET.com"
        "null"
        "https://TARGET.com"
    )
fi

if [ ! -f "$SUBS" ]; then
    echo "[ERROR] live_urls.txt introuvable. Lancer 01_subdomain_enum.sh d'abord."
    exit 1
fi

echo "[*] Testing CORS misconfigurations on $(wc -l < "$SUBS") hosts..."
> "$OUT"  # Reset output

while IFS= read -r url; do
    for origin in "${ORIGINS[@]}"; do
        RESPONSE=$(curl -sk --max-time "${BBP_TIMEOUT:-8}" -H "Origin: $origin" -I "$url" 2>/dev/null)
        ACAO=$(echo "$RESPONSE" | grep -i "access-control-allow-origin" | tr -d '\r')
        ACAC=$(echo "$RESPONSE" | grep -i "access-control-allow-credentials" | tr -d '\r')

        if echo "$ACAO" | grep -qi "$origin\|null\|\*"; then
            if echo "$ACAC" | grep -qi "true"; then
                echo "[CRITICAL] CORS + Credentials: $url | Origin: $origin | $ACAO | $ACAC" | tee -a "$OUT"
            elif echo "$ACAO" | grep -q "\*"; then
                echo "[LOW] CORS wildcard (*): $url | Origin: $origin | $ACAO" | tee -a "$OUT"
            else
                echo "[MEDIUM] CORS reflected: $url | Origin: $origin | $ACAO" | tee -a "$OUT"
            fi
        fi
    done
done < "$SUBS"

CRITICAL_COUNT=$(grep -c "CRITICAL" "$OUT" 2>/dev/null || echo 0)
echo "[+] CORS scan complete."
echo "    CRITICAL (credentials): $CRITICAL_COUNT"
echo "    Total findings:         $(wc -l < "$OUT")"
echo "    Results in: $OUT"
echo ""
echo "[!] RAPPEL: Reporter seulement si credentials:true ET données sensibles accessibles"
