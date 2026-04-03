# Bug Bounty Template — HackerOne / Bugcrowd / Intigriti

Template de pentest automatisé pour programmes de bug bounty. Entièrement configurable via `setup.env`.

---

## Démarrage rapide (nouveau programme)

```bash
# 1. Copier le template
cp -r Program-1/ Program-2/
cd Program-2/

# 2. Editer setup.env avec les infos du nouveau programme
nano setup.env

# 3. Mettre à jour config/priority_targets.txt
nano config/priority_targets.txt

# 4. Lancer le pipeline complet
source setup.env && bash RUN_ALL.sh
```

---

## Configuration (setup.env)

Toutes les variables sont dans `setup.env`. C'est le **seul fichier à modifier** pour changer de programme.

| Variable | Description | Exemple |
|----------|-------------|---------|
| `BBP_PROGRAM_NAME` | Nom du programme | `"Remitly"` |
| `BBP_PLATFORM` | Plateforme | `hackerone` / `bugcrowd` / `intigriti` |
| `BBP_DOMAINS` | Domaines racines (espace-séparés) | `"remitly.com rewire.com remitly.io"` |
| `BBP_PASSIVE_DOMAINS` | Domaines pour wayback/gau | `"remitly.com rewire.com"` |
| `BBP_FEROX_TARGET` | Cible principale pour feroxbuster | `"https://api.remitly.io"` |
| `BBP_FFUF_TARGET` | Cible pour ffuf dir brute | `"https://auth.remitly.com"` |
| `BBP_COLLAB` | URL OOB pour SSRF | `"abc123.oast.fun"` |
| `BBP_CORS_ORIGINS` | Origines CORS à tester | `"https://evil.com https://TARGET.evil.com"` |
| `BBP_SECLISTS` | Chemin SecLists | `"${HOME}/SecLists"` |
| `BBP_NUCLEI_TEMPLATES` | Chemin nuclei-templates | `"${HOME}/nuclei-templates"` |
| `BBP_THREADS_HIGH/MED/LOW` | Threads par intensité | `50` / `30` / `20` |
| `BBP_TIMEOUT` | Timeout curl/tools (secondes) | `10` |

Les cibles prioritaires (0-reports) vont dans `config/priority_targets.txt` (une URL par ligne, `#` pour commentaires).

---

## Rewards (exemple Remitly)

| Sévérité | Bounty |
|----------|--------|
| Critical | ~$9,000 |
| High     | ~$2,500 |
| Medium   | ~$400  |
| Low      | ~$50   |

---

## Scope (exemple Remitly)

### Critical
| Asset | Reports | Notes |
|-------|---------|-------|
| `remitly.com` | 85 | Cible principale |
| `api.remitly.io` | 10 | API backend |
| `auth.remitly.com` | 5 | Auth |
| `rewire.com` | 17 | |
| `*.int.remitly.com` | 2 | Wildcard |
| `cardpayments.remitly.io` | **0** | Priorité |
| `cards.remitly.io` | 1 | |
| `access.remitly.com` | **0** | Auth-related |
| `app.rewire.to` | 4 | |
| Apps mobile Android/iOS | 7 | |

### High
| Asset | Reports | Notes |
|-------|---------|-------|
| `*.dev.remitly.com` | 2 | Wildcard |
| `funding-webhooks.remitly.io` | **0** | SSRF potentiel |
| `partner-webhook.remitly.io` | **0** | SSRF potentiel |
| `access-sandbox.remitly.com` | **0** | |
| `ablink.info.remitly.com` | **0** | |
| `news.remitly.com` | 1 | |

### Medium
| Asset | Reports | Notes |
|-------|---------|-------|
| `hub-api-sandbox.remitly.io` | **0** | API sandbox |
| `careers.remitly.com` | 2 | |
| `rates.rewire.com` | 3 | |
| `metrics.int.remitly.com` | **0** | |

### Out of scope
- `https://www.remitly.com/blog`
- Path traversal sur `api.remitly.io`
- IDOR sans impact de sécurité
- Self XSS via cookies
- Password Policy
- Logout CSRF, clickjacking sans action sensible
- DoS

---

## Vulnérabilités payées (par ordre d'intérêt)

1. RCE / Command Injection / Deserialization
2. SQLi / Redis injection
3. Privilege escalation
4. Authentication flaws
5. **Stored XSS** (Type-2)
6. **SSRF**
7. CSRF (hors logout)
8. Leak de données clients
9. Reflected XSS
10. Bypass anti-brute force

---

## Structure du projet

```
Program-1/
├── setup.env                     ← CONFIG CENTRALE (modifier ici)
├── RUN_ALL.sh                    Lance tout le pipeline
├── CLAUDE.md                     Prompt LLM pour investigations
│
├── recon/
│   ├── 01_subdomain_enum.sh      subfinder + httpx + subzy
│   ├── 02_url_collection.sh      waybackurls + gau + katana + gf
│   ├── 03_screenshots.sh         Screenshots hosts vivants
│   ├── subdomains/               all_subs_raw, live_hosts, live_urls, takeover_results
│   └── urls/                     all_urls, gf_sqli/xss/ssrf/redirect/lfi, js_files
│
├── scan/
│   ├── 04_nuclei_scan.sh         Nuclei critical/high/medium + misconfigs + CORS
│   ├── 05_dirsearch_ferox.sh     Bruteforce répertoires/endpoints
│   ├── 06_secrets_scan.sh        SecretFinder + grep sur JS
│   ├── 07_cors_scan.sh           Test CORS misconfiguration
│   ├── nuclei/                   critical_high, medium_priority, cors_detail
│   ├── dirsearch/                Résultats ffuf/dirsearch/feroxbuster
│   └── secrets/                  secretfinder_results, grep_secrets
│
├── exploit/
│   ├── sqli/08_sqli_test.sh      SQLmap sur candidates gf_sqli
│   ├── ssrf/09_ssrf_test.sh      SSRF webhooks + OOB (BBP_COLLAB requis)
│   ├── xss/10_xss_test.sh        Reflection check + ffuf payloads
│   └── idor/11_idor_test.sh      Extraction candidates + checklist manuelle
│
├── loot/
│   ├── findings/findings_tracker.md   Tableau de suivi des bugs
│   └── reports/REPORT_TEMPLATE.md     Template rapport HackerOne
│
├── config/
│   ├── all_scope.txt             Scope complet (in/out)
│   └── priority_targets.txt     Cibles à 0 reports (scannées en priorité)
│
└── wordlists/
    ├── xss_payloads.txt
    └── api_paths.txt
```

---

## Workflow

### Etape 1 — Config
```bash
# Modifier setup.env avec les infos du programme
nano setup.env
nano config/priority_targets.txt
nano config/all_scope.txt
```

### Etape 2 — Recon automatique
```bash
source setup.env
bash recon/01_subdomain_enum.sh   # ~10-30 min
bash recon/02_url_collection.sh   # ~20-60 min (selon taille du programme)
```

### Etape 3 — Scans
```bash
bash scan/04_nuclei_scan.sh       # ~30-120 min selon nb de hosts
bash scan/05_dirsearch_ferox.sh   # ~20-60 min
bash scan/06_secrets_scan.sh      # ~15-30 min
bash scan/07_cors_scan.sh         # ~10-20 min
```

### Etape 4 — Review des résultats
```bash
cat scan/nuclei/critical_high.txt
cat scan/nuclei/cors_detail.txt
cat scan/secrets/grep_secrets.txt
# Toujours confirmer manuellement avant d'exploiter
```

### Etape 5 — Exploitation
```bash
# SSRF: configurer BBP_COLLAB dans setup.env d'abord
source setup.env && bash exploit/ssrf/09_ssrf_test.sh

# SQLi
bash exploit/sqli/08_sqli_test.sh

# XSS
bash exploit/xss/10_xss_test.sh

# IDOR: 2 comptes nécessaires
cat exploit/idor/IDOR_MANUAL_CHECKLIST.md
```

### Etape 6 — Report
```bash
# Remplir le tracker
nano loot/findings/findings_tracker.md

# Créer le rapport
cp loot/reports/REPORT_TEMPLATE.md loot/reports/VULN_TYPE_asset.md
nano loot/reports/VULN_TYPE_asset.md

# Soumettre sur HackerOne/Bugcrowd
```

---

## Résultats attendus par phase

**Phase 1 — Subdomain enumeration**
```
[+] subfinder done for domain.com: 50-200 subs
[+] Total unique subdomains: 100-500
[+] Live hosts: 30-70% des subs
[TAKEOVER CANDIDATE] subdomain.domain.com [Service]  → vérifier manuellement
```

**Phase 2 — URL collection**
```
[+] Passive URLs collected: 10,000+   → programmes matures
[+] Total URLs: 15,000+
    SQLi candidates:  50-200
    XSS candidates:   100-500
    SSRF candidates:  20-100
    JS files:         100-500
```

**Phase 4 — Nuclei**
```
[critical] [CVE-XXXX] https://target.com/path   → confirmer manuellement
[high]     [exposed-panel] https://target.com    → tester l'accès
[medium]   [cors-misconfig] https://target.com   → vérifier credentials:true
```
⚠️ Nuclei génère beaucoup de faux positifs. **Confirmer manuellement avant de reporter.**

**Phase 5 — Dir brute**
```
200 /api/v1/users    → tester auth
401 /admin           → bypass possible?
403 /internal        → chercher d'autres vecteurs
```
Ignorer les 404. Les 200/401/403 sont les plus intéressants.

**Phase 6 — Secrets**
```
[SecretFinder] AWS Key: AKIA...     → CRITIQUE, vérifier si active
[grep] api_key = "..."              → souvent faux positifs (valeurs exemple)
```

**Phase 7 — CORS**
```
[CRITICAL] CORS + Credentials       → à reporter si données sensibles
[MEDIUM]   CORS reflected           → impact limité sans credentials
```
Un CORS est reportable seulement si `credentials: true` ET données sensibles accessibles.

---

## Règles importantes

- Ne pas faire de DoS
- Utiliser uniquement des comptes dont on est propriétaire
- Un bug par rapport (sauf chaining nécessaire)
- Fournir des steps reproductibles + PoC
- Confirmer manuellement chaque finding avant de soumettre

---

## Outils requis

```bash
# Requis
subfinder httpx nuclei ffuf sqlmap

# Optionnels mais recommandés
katana waybackurls gau subzy feroxbuster gf

# Wordlists
git clone https://github.com/danielmiessler/SecLists ~/SecLists
nuclei -update-templates

# Secrets
git clone https://github.com/m4ll0k/SecretFinder ~/tools/SecretFinder
pip3 install -r ~/tools/SecretFinder/requirements.txt
```

---

## Checklist avant de lancer sur un nouveau programme

- [ ] Lire le scope complet sur HackerOne/Bugcrowd
- [ ] Identifier les cibles à **0 reports** → moins de duplication
- [ ] Modifier `setup.env` (BBP_DOMAINS, BBP_PROGRAM_NAME, etc.)
- [ ] Mettre à jour `config/priority_targets.txt`
- [ ] Mettre à jour `config/all_scope.txt`
- [ ] Générer une URL interactsh pour BBP_COLLAB
- [ ] Vérifier que SecLists et nuclei-templates sont à jour

---

## Adapter à un autre programme — Variables à modifier

| Variable dans setup.env | Valeur actuelle | Remplacer par |
|-------------------------|----------------|---------------|
| `BBP_PROGRAM_NAME` | `"Remitly"` | Nom du programme |
| `BBP_DOMAINS` | `"remitly.com rewire.com remitly.io"` | Domaines racines |
| `BBP_PASSIVE_DOMAINS` | `"remitly.com rewire.com"` | Domaines pour wayback/gau |
| `BBP_FEROX_TARGET` | `"https://api.remitly.io"` | API principale du programme |
| `BBP_FFUF_TARGET` | `"https://auth.remitly.com"` | Endpoint auth |
| `BBP_COLLAB` | `"REPLACE_WITH_YOUR_OOB_URL"` | URL interactsh ou webhook.site |
| `BBP_CORS_ORIGINS` | Origins avec "remitly" | Origins adaptées au domaine cible |

Fichiers à mettre à jour:
- `config/priority_targets.txt` — cibles à 0 reports du nouveau programme
- `config/all_scope.txt` — scope complet (copié depuis HackerOne)
