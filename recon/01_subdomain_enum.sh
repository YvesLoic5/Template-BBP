#!/bin/bash
# ============================================================
#  PHASE 1 — Subdomain Enumeration
#  Variables: BBP_DOMAINS, BBP_BASE
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -z "$BBP_BASE" ] && source "$SCRIPT_DIR/setup.env"

OUT="${BBP_BASE}/recon/subdomains"
mkdir -p "$OUT"

echo "[*] Starting subdomain enumeration for: ${BBP_DOMAINS}"

for DOMAIN in ${BBP_DOMAINS}; do
    echo "[*] Enumerating: $DOMAIN"
    subfinder -d "$DOMAIN" -all -silent -o "${OUT}/subfinder_${DOMAIN}.txt"
    echo "[+] subfinder done for $DOMAIN: $(wc -l < "${OUT}/subfinder_${DOMAIN}.txt") subs"
done

# Merge all
cat "${OUT}"/subfinder_*.txt 2>/dev/null | sort -u > "${OUT}/all_subs_raw.txt"
echo "[+] Total unique subdomains: $(wc -l < "${OUT}/all_subs_raw.txt")"

# Probe live hosts
echo "[*] Probing live hosts with httpx..."
httpx -l "${OUT}/all_subs_raw.txt" \
    -status-code \
    -title \
    -tech-detect \
    -content-length \
    -follow-redirects \
    -timeout "${BBP_TIMEOUT:-10}" \
    -threads "${BBP_THREADS_HIGH:-50}" \
    -o "${OUT}/live_hosts.txt"

awk '{print $1}' "${OUT}/live_hosts.txt" > "${OUT}/live_urls.txt"
echo "[+] Live hosts: $(wc -l < "${OUT}/live_urls.txt")"

# Subdomain takeover check
echo "[*] Checking subdomain takeover with subzy..."
subzy run --targets "${OUT}/all_subs_raw.txt" --output "${OUT}/takeover_results.txt" 2>/dev/null
grep -i "VULNERABLE" "${OUT}/takeover_results.txt" 2>/dev/null | while read -r line; do
    echo "[TAKEOVER CANDIDATE] $line"
done

echo "[+] Done. Results in ${OUT}/"
