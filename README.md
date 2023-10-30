# NUT & esNUT Token Contracts

This repository contains the smart contracts for the NUT and esNUT tokens, designed for governance and vesting purposes.

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
    - [Patch EIP712.sol](#patch)
3. [Contract Overview](#contract-overview)
    - [NUT](#nut)
    - [esNUT](#esnut)
4. [Usage](#usage)
5. [Testing](#testing)
6. [Security](#security)
7. [License](#license)

## Introduction

- NUT: A standard ERC20 token with minting and pausing capabilities. It represents a vested token that can be unlocked from its counterpart, esNUT.
- esNUT: Represents a locked governance token. It's non-transferable by default but can be unlocked to obtain NUT tokens.

## Installation

```bash
git clone https://github.com/ezoia-com/nut
cd nut
mkdir node_modules
npm install @openzeppelin/contracts@4.9.0 --save
```

### Patch
Using ShortStrings for *;" triggers a bug in Brownie. This can be solved by expliciting the the using in node_modules/@openzeppelin/contracts/utils/cryptography/EIP712.sol

Replace

    using ShortStrings for *;
  
   to
    
    using ShortStrings for string;
    using ShortStrings for ShortString;

## Contract Overview

### NUT

- Inherits from OpenZeppelin's `ERC20PresetMinterPauser` and `ERC20Capped`.
- Has capabilities for minting, burning, and pausing token transfers.
- Capped at \(1e28\) tokens.

### esNUT

- Inherits from OpenZeppelin's `ERC20`, `ERC20Permit`, `ERC20Votes`, and `AccessControlEnumerable`.
- Represents the locked version of the NUT token.
- Has roles for transferring and unlocking tokens.
- Contains functions to lock NUT and unlock esNUT.
- Transferability can be toggled.

## Usage

**NUT:**

- `burn(address account, uint256 amount)`: Allows an account with the `MINTER_ROLE` to burn NUT tokens.

**esNUT:**

- `unlock(address account, uint unlockAmount)`: Converts esNUT to NUT for a specified account.
- `lock(uint256 amount)`: Converts NUT to esNUT.
- `setTokenLock(bool _tokenLocked)`: Toggles the transferability of esNUT.

## Testing

Ensure you have [Eth Brownie](https://github.com/eth-brownie/brownie) installed.

Run the tests with:

```bash
brownie test --network mainnet-fork
```

## Security

- This code base has not yet been audited.

## License

This project is licensed under the `SPDX-License-Identifier: none`.
