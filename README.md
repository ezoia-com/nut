

# NUT & esNUT Token Contracts

This repository contains the smart contracts for the NUT and esNUT tokens, designed for governance and vesting purposes.

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
    - [Patch EIP712.sol](#patch)
3. [Contract Overview](#contract-overview)
    - [NUT](#nut)
    - [esNUT](#esnut)
    - [LinearVesting](#linearvesting)
    - [ScheduledVesting](#scheduledvesting)
4. [Usage](#usage)
5. [Testing](#testing)
6. [Coverage](#coverage)
7. [Security](#security)
8. [License](#license)

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

### Code specification
https://docs.google.com/document/d/10FSR7hgw6R0Z9_8j8eEFnzeE2-2X2NtAdP-DM2Ybo6w/edit

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

### LinearVesting
 - This contract allows users to lock their esNUT tokens and linearly vest them into NUT over a period of 90 days. 

### ScheduledVesting

 - This contract provides customized vesting schedules for each address. 

## Usage

**NUT:**

- `burn(address account, uint256 amount)`: Allows an account with the `MINTER_ROLE` to burn NUT tokens.

**esNUT:**

- `unlock(address account, uint unlockAmount)`: Converts esNUT to NUT for a specified account.
- `lock(uint256 amount)`: Converts NUT to esNUT.
- `setTokenLock(bool _tokenLocked)`: Toggles the transferability of esNUT.


**LinearVesting:**

- `startVesting(uint256 amount)`: Start a new 90-day linear vesting schedule with a specified amount of esNUT.
- `claimVestedTokens()`: Allows a user to claim any NUT tokens that have vested since the last claim or the start of the vesting.
- `lock(uint256 duration, uint256 amount)`: Users can set a lock duration and amount, preventing them from vesting if there's an insufficient esNUT balance.
- `earlyWithdraw()`: Users can withdraw their esNUT before the vesting period ends but will incur a penalty.
- `overrideLockEndTime(uint256 timestamp, uint256 esnutLocked)`: The admin can set a future timestamp for an address, indicating that the address can't start vesting through this contract until that timestamp.

**ScheduledVesting:**
- `setSchedule(address account, VestingSchedule[] memory newSchedule)`: Admins can set a unique vesting schedule for a user. The schedule is an array of timestamps and amounts.
- `vestTokens()`: Allows a user to claim their NUT tokens based on the predetermined schedule set by the admin.
- `cancelSchedule(address account)`: Admins can cancel a user's vesting schedule. On canceling, any vested tokens according to the existing schedule are first unlocked.


## Testing

Ensure you have [Eth Brownie](https://github.com/eth-brownie/brownie) installed.

Run the tests with:

```bash
brownie test --network mainnet-fork
```

## Coverage

Perform coverage with:
```bash	
brownie test --network mainnet-fork --coverage
```

Current coverage:

      contract: LinearVesting
        LinearVesting.startVesting - 83.3%
        LinearVesting.claimVestedTokens - 75.0%
        LinearVesting.lock - 75.0%
        LinearVesting.overrideLockEndTime - 75.0%
        LinearVesting.earlyWithdraw - 70.5%
    
      contract: ScheduledVesting
        ScheduledVesting.vestTokens - 100.0%
        ScheduledVesting.setSchedule - 87.5%
        ScheduledVesting.cancelSchedule - 62.5%


## Security

- This code base has not yet been audited.

## License

This project is licensed under the `SPDX-License-Identifier: none`.
