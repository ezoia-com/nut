// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from '../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {MerkleProof} from '../../node_modules/@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';
import {Ownable} from '../../node_modules/@openzeppelin/contracts/access/Ownable.sol';
import {SafeERC20} from "../node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


// Allows anyone to claim a token if they exist in a merkle root.
interface IMerkleDistributor {
    // Returns the address of the token distributed by this contract.
    function token() external view returns (address);

    // Returns the merkle root of the merkle tree containing account balances available to claim.
    function merkleRoot() external view returns (bytes32);

    // Returns true if the index has been marked claimed.
    function isClaimed(uint256 index) external view returns (bool);

    // Claim the given amount of the token to the given address. Reverts if the inputs are invalid.
    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external;

    // This event is triggered whenever a call to #claim succeeds.
    event Claimed(uint256 index, address account, uint256 amount);
}

contract MerkleDistributor is IMerkleDistributor, Ownable {
    using SafeERC20 for IERC20;

    address public immutable override token;
    bytes32 public immutable override merkleRoot;

    // This is a packed array of booleans.
    mapping(uint256 => uint256) private claimedBitMap;

    constructor(address token_, bytes32 merkleRoot_) Ownable() {
        token = token_;
        merkleRoot = merkleRoot_;
    }

    function isClaimed(uint256 index) public view override returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] =
            claimedBitMap[claimedWordIndex] |
            (1 << claimedBitIndex);
    }

    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external override {
        require(!isClaimed(index), 'MerkleDistributor: Drop already claimed.');

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            'MerkleDistributor: Invalid proof.'
        );

        // Mark it claimed and send the token.
        _setClaimed(index);
        require(
            IERC20(token).transfer(account, amount),
            'MerkleDistributor: Transfer failed.'
        );

        emit Claimed(index, account, amount);
    }

    /**
     * @notice Transfers all of an ERC20 token from this contract to a target address.
     * @dev Only callable by Owner.
     * @param tokenAddress The address of the ERC20 token to be transferred.
     * @param target The address that will receive the ERC20 tokens.
     */
    function rescueERC20(address tokenAddress, address target) external onlyOwner {
        IERC20(tokenAddress).safeTransfer(target, IERC20(tokenAddress).balanceOf(address(this)));
    }

}
