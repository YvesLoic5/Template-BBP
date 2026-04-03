#!/bin/bash
# ============================================================
#  MASTER SCRIPT — Bug Bounty Recon Pipeline
#  Usage: source setup.env && bash RUN_ALL.sh
#  Ou:    bash RUN_ALL.sh (charge setup.env automatiquement)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger la config si pas déjà chargée
if [ -z "$BBP_BASE" ]; then
    if [ -f "$SCRIPT_DIR/setup.env" ]; then
        source "$SCRIPT_DIR/setup.env"
    else
        echo "[ERROR] setup.env introuvable. Copier depuis le template et configurer."
        exit 1
    fi
fi

LOG="${BBP_BASE}/run_all.log"

echo "======================================================"
echo "  ${BBP_PROGRAM_NAME} Bug Bounty — Recon Pipeline"
echo "  Platform: ${BBP_PLATFORM}"
echo "  Started: $(date)"
echo "======================================================"

run_phase() {
    local script=$1
    local name=$2
    echo ""
    echo "[PHASE] $name"
    echo "------------------------------------------------------"
    bash "$script" 2>&1 | tee -a "$LOG"
    local exit_code=${PIPESTATUS[0]}
    echo "[DONE] $name — $(date) (exit: $exit_code)"
    return $exit_code
}

run_phase "${BBP_BASE}/recon/01_subdomain_enum.sh"   "Subdomain Enumeration"
run_phase "${BBP_BASE}/recon/02_url_collection.sh"   "URL Collection"
# run_phase "${BBP_BASE}/recon/03_screenshots.sh"    "Screenshots (optionnel)"
run_phase "${BBP_BASE}/scan/04_nuclei_scan.sh"        "Nuclei Vulnerability Scan"
run_phase "${BBP_BASE}/scan/05_dirsearch_ferox.sh"    "Directory Bruteforce"
run_phase "${BBP_BASE}/scan/06_secrets_scan.sh"       "Secret Discovery"
run_phase "${BBP_BASE}/scan/07_cors_scan.sh"          "CORS Misconfiguration"

echo ""
echo "======================================================"
echo "  Recon automatique terminé!"
echo ""
echo "  Etapes manuelles suivantes:"
echo "  1. Reviewer: scan/nuclei/, scan/secrets/, scan/dirsearch/"
echo "  2. SSRF: configurer BBP_COLLAB dans setup.env puis:"
echo "           bash exploit/ssrf/09_ssrf_test.sh"
echo "  3. SQLi: bash exploit/sqli/08_sqli_test.sh"
echo "  4. XSS:  bash exploit/xss/10_xss_test.sh"
echo "  5. IDOR: cat exploit/idor/IDOR_MANUAL_CHECKLIST.md"
echo "  6. Remplir: loot/findings/findings_tracker.md"
echo "======================================================"
