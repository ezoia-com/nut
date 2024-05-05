// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "./MerkleDistributor.sol"; // Import the MerkleDistributor contract

contract MultiClaim {
    struct ClaimParam {
        MerkleDistributor merkleAddress;
        uint256 index;
        address account;
        uint256 amount;
        bytes32[] merkleProof;
    }

    /**
     * @notice Processes multiple claims in a single transaction.
     * @param claims An array of claims to process.
     */
    function multiClaim(ClaimParam[] calldata claims) external {
        for (uint256 i = 0; i < claims.length; i++) {
            ClaimParam calldata claim = claims[i];
            claim.merkleAddress.claim(
                    claim.index,
                    claim.account,
                    claim.amount,
                    claim.merkleProof
            );
        }
    }
}
