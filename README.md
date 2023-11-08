


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
    - [MerkleDistributor](#merkledistributor)
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

### MerkleDistributor

- This contract allows anyone to receive some quantities of a token if the claim is encoded in the Merkle tree, by providing the Merkle Proof

## Usage

**NUT:**

- `mint(address account, uint256 amount)`: Allows an account with the `MINTER_ROLE` to mint NUT tokens.
- `burn(address account, uint256 amount)`: Allows an account with the `MINTER_ROLE` to burn NUT tokens.

**esNUT:**

- `mint(address to, uint256 amount)`: Allows account with DEFAULT_ADMIN_ROLE to mint esNUT to another account
- `burn(uint256 amount)`: Allows account with DEFAULT_ADMIN_ROLE to burn esNUT in its account
- `unlock(address account, uint unlockAmount)`: Converts esNUT to NUT for a specified account.
- `lock(uint256 amount)`: Converts NUT to esNUT.
- `setTokenLock(bool _tokenLocked)`: Toggles the transferability of esNUT.


**LinearVesting:**

- `startVesting(uint256 amount)`: Start a new 90-day linear vesting schedule with a specified amount of esNUT.
- `claimVestedTokens()`: Allows a user to claim any NUT tokens that have vested since the last claim or the start of the vesting.
- `lock(uint256 duration, uint256 amount)`: Users can set a lock duration and amount, preventing them from vesting if there's an insufficient esNUT balance.
- `earlyWithdraw()`: Users can withdraw their esNUT before the vesting period ends but will incur a penalty.
- `overrideLockEndTime(uint256 timestamp, uint256 esnutLocked)`: The admin can set a future timestamp for an address, indicating that the address can't start vesting through this contract until that timestamp.
- `setMinPenalty(uint256 _minPenalty)`: The admin can set a minimum penalty between 0 to 100%

**ScheduledVesting:**
- `setSchedule(address account, VestingSchedule[] memory newSchedule)`: Admins can set a unique vesting schedule for a user. The schedule is an array of timestamps and amounts.
- `vestTokens()`: Allows a user to claim their NUT tokens based on the predetermined schedule set by the admin.
- `cancelSchedule(address account)`: Admins can cancel a user's vesting schedule. On canceling, any vested tokens according to the existing schedule are first unlocked.

**MerkleDistributor**

-   `token() -> address`: Returns the address of the token that is being distributed by this contract.    
-   `merkleRoot() -> bytes32`: Returns the Merkle root of the tree containing account balances available for claim.
-   `isClaimed(uint256 index) -> bool`: Takes an `index` as an argument and returns `true` if the index has already been marked as claimed, and `false` otherwise.
-   `claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof)`: Allows an account to claim a specified `amount` of the token if they provide a valid Merkle proof (`merkleProof`) that corresponds to the `index`, `account`, and `amount`.
    -   **Note**: If the claim is valid, the tokens will be transferred to the `account`, and the index will be marked as claimed.
    -   **Events**: Emits a `Claimed` event upon successful claim.
-   `rescueERC20(address tokenAddress, address target)`: Allows **only the owner** of the contract to transfer the entirety of any ERC20 `tokenAddress`'s balance held by this contract to a specified `target` address.
    -   **Note**: This function is primarily designed for distribution finalization or cancellation by transferring out the remaining tokens from the contract. 

## Testing

Ensure you have [Eth Brownie](https://github.com/eth-brownie/brownie) installed.

Run the tests with:

```bash
brownie test --network mainnet-fork
```
Example output

	Brownie v1.19.3 - Python development framework for Ethereum
	==================================================================================================== test session starts ====================================================================================================
	platform linux -- Python 3.8.10, pytest-6.2.5, py-1.11.0, pluggy-1.0.0
	rootdir: ~/thetanuts/nut
	plugins: eth-brownie-1.19.3, anyio-3.6.2, xdist-1.34.0, forked-1.4.0, hypothesis-6.27.3, requests-mock-1.6.0, web3-5.31.3
	collected 12 items

	Launching 'ganache-cli --port 8545 --gasLimit 12000000 --accounts 10 --hardfork istanbul --mnemonic brownie'...

	tests/test_deployment.py .........                                                                                                                                                                                    [ 75%]
	tests/test_gov.py ..                                                                                                                                                                                                  [ 91%]
	tests/test_merkle.py .                                                                                                                                                                                                

## Coverage

Perform coverage with:
```bash	
brownie test --coverage
```

Current coverage (hiding OpenZeppelin's contracts):

	  contract: LinearVesting - 68.8%
	    LinearVesting.claimVestedTokens - 100.0%
	    LinearVesting.earlyWithdraw - 100.0%
	    LinearVesting.lock - 100.0%
	    LinearVesting.overrideLockEndTime - 100.0%
	    LinearVesting.setMinPenalty - 100.0%
	    LinearVesting.startVesting - 91.7%

	  contract: ScheduledVesting - 50.7%
	    ScheduledVesting.setSchedule - 100.0%
	    ScheduledVesting.vestTokens - 100.0%


## Security
- This code base has not yet been audited.

## License

This project is licensed under the `SPDX-License-Identifier: none`.
