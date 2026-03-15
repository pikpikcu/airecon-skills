# Shodan, Censys & Internet-Wide Recon

Passive attack surface discovery using search engines that index the internet: open ports, services, certificates, banners, and misconfigurations — without touching the target.

## Install

```bash
# Shodan CLI:
pip install shodan --break-system-packages
shodan init <YOUR_API_KEY>   # get key from https://account.shodan.io

# Censys CLI:
pip install censys --break-system-packages
censys config   # enter API_ID and API_SECRET from https://search.censys.io/account

# FOFA (Chinese internet scanner — great for Asia-Pacific targets):
pip install fofa --break-system-packages
# OR: use web interface at https://fofa.info

# Netlas (alternative):
pip install netlas --break-system-packages
netlas --api_key <KEY>

# BGP/ASN tools:
sudo apt-get install -y whois
pip install ipwhois --break-system-packages
```

---

## Phase 1: ASN & IP Range Discovery

```bash
# Find ASN for organization:
whois -h whois.radb.net -- '-i origin AS<number>'
whois <company_domain> | grep -i "asn\|origin\|netname\|inetnum"

# Convert ASN to IP ranges:
python3 -c "
from ipwhois import IPWhois
from ipwhois.net import Net
from ipwhois.asn import IPASN
# Get IP ranges for ASN:
import urllib.request, json
asn = 'AS15169'  # Google example
url = f'https://api.bgpview.io/asn/{asn}/prefixes'
data = json.loads(urllib.request.urlopen(url).read())
for prefix in data['data']['ipv4_prefixes']:
    print(prefix['prefix'])
"

# Shodan ASN search:
shodan search "asn:AS15169" --fields ip_str,port,org
shodan stats "asn:AS15169"

# Bulk IP range from ARIN/RIPE:
whois -h whois.arin.net "n + <org_name>"
```

---

## Phase 2: Shodan — Core Queries

```bash
# Basic host lookup:
shodan host <IP_ADDRESS>          # all open ports, banners, location
shodan host <IP_ADDRESS> --history   # historical data

# Search by organization:
shodan search "org:\"Target Company\"" --fields ip_str,port,data
shodan search "org:\"Target Company\" port:22" --fields ip_str,data

# Search by hostname/domain:
shodan search "hostname:target.com" --fields ip_str,port,hostnames
shodan search "ssl.cert.subject.cn:*.target.com"   # wildcard SSL certs

# Search by IP range (CIDR):
shodan search "net:192.168.1.0/24" --fields ip_str,port,org

# Output formats:
shodan search "org:\"Target\"" --limit 100 --fields ip_str,port,transport -o results.csv
shodan download results.json.gz "org:\"Target\""   # download full result set
shodan parse results.json.gz --fields ip_str,port  # parse downloaded results
```

---

## Phase 3: Shodan — Service-Specific Queries

```bash
# Exposed admin panels:
shodan search "org:\"Target\" http.title:\"admin\""
shodan search "org:\"Target\" http.title:\"Dashboard\""

# Default credentials:
shodan search "org:\"Target\" \"default password\""
shodan search "org:\"Target\" http.html:\"admin\" \"default\""

# Exposed databases:
shodan search "org:\"Target\" port:27017"   # MongoDB
shodan search "org:\"Target\" port:6379"    # Redis
shodan search "org:\"Target\" port:9200"    # Elasticsearch
shodan search "org:\"Target\" port:5432"    # PostgreSQL
shodan search "org:\"Target\" port:3306"    # MySQL

# Exposed dev/staging:
shodan search "org:\"Target\" http.title:\"staging\""
shodan search "hostname:\"dev.target.com\" OR hostname:\"staging.target.com\""

# Git/config file exposure:
shodan search "org:\"Target\" http.html:\".git\""
shodan search "org:\"Target\" http.html:\"config.php\""

# Industrial / IoT:
shodan search "org:\"Target\" port:102"    # Siemens S7
shodan search "org:\"Target\" port:502"    # Modbus
shodan search "org:\"Target\" port:47808"  # BACnet

# Specific banner content:
shodan search "org:\"Target\" \"server: apache/2.2\""
shodan search "org:\"Target\" product:nginx version:1.14"

# SSL certificate recon:
shodan search "ssl.cert.subject.cn:target.com"
shodan search "ssl.cert.issuer.cn:\"Let's Encrypt\" hostname:target.com"

# HTTP response body:
shodan search "org:\"Target\" http.html:\"internal_api_key\""
shodan search "org:\"Target\" http.html:\"aws_access_key\""
```

---

## Phase 4: Censys — Core Queries

```bash
# CLI searches (Censys v2 API):
censys search "target.com" --index-type hosts
censys search "target.com" --index-type certs

# Python API:
python3 -c "
from censys.search import CensysHosts
h = CensysHosts()
# Search by domain in TLS certificate:
for result in h.search('services.tls.certificates.leaf_data.subject.common_name: target.com', per_page=25):
    print(result['ip'], result.get('services', []))
"

# Certificate transparency via Censys:
python3 -c "
from censys.search import CensysCertificates
c = CensysCertificates()
for cert in c.search('parsed.names: target.com', fields=['parsed.names', 'parsed.subject.common_name']):
    print(cert)
"

# Find subdomains via SSL cert SAN:
censys search "services.tls.certificates.leaf_data.subject.common_name: *.target.com" \
  --index-type hosts --fields "ip,services.port,services.service_name"
```

---

## Phase 5: Certificate Transparency (Passive Subdomain Discovery)

```bash
# crt.sh — largest CT log aggregator:
curl -s "https://crt.sh/?q=%25.target.com&output=json" | \
  python3 -c "import sys,json; [print(c['name_value']) for c in json.load(sys.stdin)]" | \
  sort -u | grep -v "^\*"

# With subfinder (uses CT + Shodan + Censys):
subfinder -d target.com -silent

# amass passive (CT + multiple sources, no active DNS):
amass enum -passive -d target.com -o subdomains.txt

# Extract unique domains from CT output:
curl -s "https://crt.sh/?q=%.target.com&output=json" 2>/dev/null | \
  python3 -m json.tool | grep "name_value" | \
  sed 's/.*: "//;s/".*//' | tr ',' '\n' | sort -u > ct_subdomains.txt
```

---

## Phase 6: FOFA Queries

```bash
# FOFA uses different syntax (domain, ip, title, cert, etc.):
# Access via web: https://fofa.info

# CLI (unofficial):
python3 -c "
import requests, base64, os
api_key = os.environ['FOFA_KEY']
email   = os.environ['FOFA_EMAIL']
query = 'domain=\"target.com\" && port=\"443\"'
q_b64 = base64.b64encode(query.encode()).decode()
url = f'https://fofa.info/api/v1/search/all?email={email}&key={api_key}&qbase64={q_b64}&fields=ip,port,title,host'
r = requests.get(url).json()
for item in r.get('results', []):
    print(item)
"

# Useful FOFA queries:
# cert=\"target.com\"              — by certificate
# title=\"Login\" && domain=\"target.com\"  — login pages
# app=\"Apache\" && domain=\"target.com\"   — Apache servers
# header=\"X-Powered-By: PHP\"              — PHP apps
# body=\"wp-content\"                        — WordPress
```

---

## Phase 7: Shodan Monitor & Alerts (Bug Bounty)

```bash
# Set up alert for new IPs belonging to target:
shodan alert create "target_monitor" "org:\"Target Company\""
shodan alert list
shodan alert info <alert_id>

# Trigger scan on demand (requires credits):
shodan scan submit 192.168.1.0/24
shodan scan status <scan_id>

# Shodan trends (historical data):
shodan stats --history "org:\"Target\"" port
```

---

## Phase 8: Automated Attack Surface Script

```bash
# Full passive recon pipeline:
TARGET="target.com"
ORG="Target Company Inc"

# 1. Find IPs via Shodan:
shodan search "org:\"$ORG\"" --fields ip_str -o shodan_ips.txt 2>/dev/null

# 2. Find subdomains via CT:
curl -s "https://crt.sh/?q=%25.$TARGET&output=json" | \
  python3 -c "import sys,json; [print(c['name_value']) for c in json.load(sys.stdin)]" | \
  sort -u | grep -v "^\*" > ct_subs.txt

# 3. Resolve subdomains:
cat ct_subs.txt | httpx -silent -ip -status-code -title -tech-detect \
  -o resolved_subs.txt 2>/dev/null

# 4. Check for exposed services on discovered IPs:
cat shodan_ips.txt | while read ip; do
    shodan host "$ip" 2>/dev/null | grep -E "^Ports:|Open ports"
done > exposed_ports.txt

# 5. Check for exposed admin/DB ports:
grep -E "27017|6379|9200|5432|3306|8080|8443" exposed_ports.txt > risky_ports.txt
cat risky_ports.txt
```

---

## Pro Tips

1. **SSL certificates** — `ssl.cert.subject.cn:*.target.com` in Shodan finds ALL subdomains with valid certs
2. **crt.sh wildcard** — `%.target.com` returns ALL certificates ever issued (including dev/internal)
3. **Shodan `net:`** — use discovered CIDR ranges for bulk scanning of entire IP space
4. **Historical data** — `shodan host <ip> --history` shows port changes over time (good for scope changes)
5. **FOFA for IoT** — better coverage than Shodan for Asian/Chinese targets
6. **Combine sources** — `subfinder -d target.com` queries Shodan + Censys + CT logs simultaneously
7. **Censys for certs** — finds wildcard certs exposing *all* subdomains in SAN field

## Summary

Internet recon flow: ASN lookup → `shodan search "org:..."` for IPs/services → `crt.sh` + `subfinder` for subdomains → `httpx` to probe live hosts → `shodan host <ip>` for port details → flag risky ports (27017/6379/9200) for direct testing.
