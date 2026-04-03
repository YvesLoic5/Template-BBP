#!/bin/bash
# ============================================================
#  PHASE 2 — URL Collection (wayback, gau, katana, gf)
#  Variables: BBP_PASSIVE_DOMAINS, BBP_PRIORITY_TARGETS_FILE
#  Run after 01_subdomain_enum.sh
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -z "$BBP_BASE" ] && source "$SCRIPT_DIR/setup.env"

OUT="${BBP_BASE}/recon/urls"
SUBS="${BBP_BASE}/recon/subdomains/live_urls.txt"
mkdir -p "$OUT"

# --- Passive collection ---
echo "[*] Collecting URLs from passive sources..."
for DOMAIN in ${BBP_PASSIVE_DOMAINS}; do
    echo "[*] waybackurls: $DOMAIN"
    waybackurls "$DOMAIN" >> "${OUT}/wayback_raw.txt" 2>/dev/null
    echo "[*] gau: $DOMAIN"
    gau "$DOMAIN" --subs >> "${OUT}/gau_raw.txt" 2>/dev/null
done

cat "${OUT}/wayback_raw.txt" "${OUT}/gau_raw.txt" 2>/dev/null | sort -u > "${OUT}/passive_urls.txt"
echo "[+] Passive URLs collected: $(wc -l < "${OUT}/passive_urls.txt")"

# --- Active crawl on priority targets ---
echo "[*] Active crawl with Katana on priority targets..."
if [ -f "${BBP_PRIORITY_TARGETS_FILE}" ]; then
    while IFS= read -r TARGET; do
        [[ "$TARGET" =~ ^#.*$ || -z "$TARGET" ]] && continue
        SAFE_NAME=$(echo "$TARGET" | sed 's/[^a-zA-Z0-9]/_/g')
        echo "[*] Katana: $TARGET"
        katana -u "$TARGET" \
            -d 4 \
            -jc \
            -ef css,png,jpg,gif,ico,woff,woff2,ttf,svg \
            -o "${OUT}/katana_${SAFE_NAME}.txt" \
            -silent 2>/dev/null
        echo "[+] Katana done: $TARGET"
    done < "${BBP_PRIORITY_TARGETS_FILE}"
else
    echo "[WARN] priority_targets.txt introuvable: ${BBP_PRIORITY_TARGETS_FILE}"
fi

cat "${OUT}"/katana_*.txt 2>/dev/null | sort -u > "${OUT}/active_urls.txt"
cat "${OUT}/passive_urls.txt" "${OUT}/active_urls.txt" 2>/dev/null | sort -u > "${OUT}/all_urls.txt"
echo "[+] Total URLs: $(wc -l < "${OUT}/all_urls.txt")"

# --- Pattern extraction ---
echo "[*] Extracting interesting patterns..."

# gf si disponible, sinon regex manuel
if command -v gf &>/dev/null && gf sqli /dev/null &>/dev/null 2>&1; then
    cat "${OUT}/all_urls.txt" | gf sqli    > "${OUT}/gf_sqli.txt"
    cat "${OUT}/all_urls.txt" | gf xss     > "${OUT}/gf_xss.txt"
    cat "${OUT}/all_urls.txt" | gf ssrf    > "${OUT}/gf_ssrf.txt"
    cat "${OUT}/all_urls.txt" | gf redirect > "${OUT}/gf_redirect.txt"
    cat "${OUT}/all_urls.txt" | gf lfi     > "${OUT}/gf_lfi.txt"
else
    echo "[*] gf patterns non installés, utilisation de regex manuels..."
    grep -iP '[?&](id|user_id|order_id|num|page|cat|ref|sort|year|month|val|item|load|next|prev|offset)\=' \
        "${OUT}/all_urls.txt" | grep -v "\.css\|\.js\|\.png\|\.jpg" | sort -u > "${OUT}/gf_sqli.txt"
    grep -iP '[?&](q|query|search|keyword|s|term|name|input|text|data|value|message|comment|title|desc)\=' \
        "${OUT}/all_urls.txt" | grep -v "\.css\|\.js\|\.png\|\.jpg" | sort -u > "${OUT}/gf_xss.txt"
    grep -iP '[?&](url|uri|link|src|source|dest|destination|redirect|return|target|path|callback|next|goto|file|fetch|load|open|host|endpoint)\=' \
        "${OUT}/all_urls.txt" | sort -u > "${OUT}/gf_ssrf.txt"
    grep -iP '[?&](redirect|return|next|url|goto|target|redir|return_url|ReturnUrl|returnTo|continue|dest)\=' \
        "${OUT}/all_urls.txt" | sort -u > "${OUT}/gf_redirect.txt"
    grep -iP '[?&](file|path|dir|document|page|pg|include|inc|locate|view|folder|root|template|res)\=' \
        "${OUT}/all_urls.txt" | sort -u > "${OUT}/gf_lfi.txt"
fi

# Also extract params broadly
cat "${OUT}/all_urls.txt" | grep "?" | sort -u > "${OUT}/gf_params.txt"
grep "\.js$" "${OUT}/all_urls.txt" | sort -u > "${OUT}/js_files.txt"

echo "[+] Pattern extraction results:"
echo "    SQLi candidates:  $(wc -l < "${OUT}/gf_sqli.txt")"
echo "    XSS candidates:   $(wc -l < "${OUT}/gf_xss.txt")"
echo "    SSRF candidates:  $(wc -l < "${OUT}/gf_ssrf.txt")"
echo "    Open redirect:    $(wc -l < "${OUT}/gf_redirect.txt")"
echo "    LFI candidates:   $(wc -l < "${OUT}/gf_lfi.txt")"
echo "    JS files:         $(wc -l < "${OUT}/js_files.txt")"
echo "[+] Done. Results in ${OUT}/"
