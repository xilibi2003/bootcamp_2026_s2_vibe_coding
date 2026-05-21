# Project Notes

## Overview

This repository is a Foundry-based Solidity demo project.

## Repository Layout

- `src/` contract sources
- `test/` unit tests
- `script/` deployment scripts
- `broadcast/` broadcast artifacts
- `out/` compiler artifacts

Current core contracts:

- `src/Bank.sol`
- `src/BigBank.sol`
- `src/Admin.sol`
- `src/TokenBank.sol`
- `src/MyToken.sol`

The token side is based on ERC1363. `TokenBank` supports both:

- `deposit(uint256)` via ERC20 `transferFrom`
- `onTransferReceived(...)` via ERC1363 callback



## Build And Test

```bash
forge build
forge test
```

Targeted test runs:

```bash
forge test --match-path test/TokenBank.t.sol
forge test --match-path test/TokenBankFork.t.sol -vv
```

## Deployment

Deploy `MyToken` on Sepolia with a keystore account:

```bash
forge script script/DeployMyToken.s.sol:DeployMyTokenScript \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --account mytoken-sepolia \
  --broadcast \
  --verify \
  --etherscan-api-key "$ETHERSCAN_API_KEY"
```
 
 
## Working Rules

- Do not revert unrelated user changes.
- Prefer minimal, local edits.
- Keep deployment secrets out of git.
- `.env`, `.keys`, `broadcast/`, `cache/`, and `out/` should stay uncommitted.

