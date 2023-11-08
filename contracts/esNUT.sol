// SPDX-License-Identifier: None
pragma solidity 0.8.19;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "../node_modules/@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./NUT.sol";

/**
 * @title esNUT Token Contract
 * @dev esNUT is an ERC20 token with voting capabilities and extended access controls.
 * It represents a locked version of the NUT token, with functionalities to unlock and lock.
 * It maintains an invariant: total supply of esNUT + total supply of NUT = 10 billion.
 */
contract esNUT is ERC20, ERC20Permit, ERC20Votes, AccessControlEnumerable {
    using SafeERC20 for ERC20;

    // Reference to the NUT token
    NUT public immutable nutToken;

    // Indicates whether the token transfers are locked or unlocked
    bool public tokenLocked; 
 
    /// @notice Access role for addresses who are allowed to receive/transfer esNUT 
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

    /// @notice Access role for addresses who are allowed to unlock esNUT 
    bytes32 public constant UNLOCK_ROLE = keccak256("UNLOCK_ROLE");

    /**
     * @notice Constructor for the esNUT token
     * @param _nutToken Address of the NUT token
     */
    constructor(address _nutToken)
        ERC20("NUT Governance Token", "esNUT")
        ERC20Permit("NUT Governance Token")
    {
        nutToken = NUT(_nutToken);
        tokenLocked = true;  // Transfer is locked by default
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(TRANSFER_ROLE, msg.sender);
    }

    // Overrides for ERC20Votes
    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

    /**
     * @notice Override for _beforeTokenTransfer. Adds additional checks for transfer restrictions and pausing.
     * @param from Address transferring from
     * @param to Address transferring to
     * @param amount Amount of tokens being transferred
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        // Check for regular transfers, and verify tokenLocked and pausing state
        if (from != address(0) && to != address(0) && tokenLocked) {
            require(hasRole(TRANSFER_ROLE, from) || hasRole(TRANSFER_ROLE, to), "esNUT: Neither sender nor recipient has TRANSFER_ROLE");
        }
        require(nutToken.paused() == false, "Paused");  // If NUT token is paused, esNUT should also be paused
    }

    // Modifier to ensure the invariant between esNUT and NUT total supplies
    modifier checkInvariantAfter {
        _;
        require(nutToken.totalSupply() + totalSupply() <= nutToken.cap(), "esNUT: NUT + esNUT invariant breached");
    }

    /**
     * @notice Allows admin role accounts to mint esNUT - this is likely deployer and eventually governance
     * @param to Address to mint to
     * @param amount Amount of esNUT to mint
     */   
    function mint(address to, uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) checkInvariantAfter {        
        _mint(to, amount);
    }
    
    /**
     * @notice Allows admin role accounts to burn esNUT - this is likely deployer and eventually governance
     * @param amount Amount of esNUT to burn
     */
    function burn(uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _burn(msg.sender, amount);
    }
    
    /**
     * @notice Allows specified accounts to unlock esNUT into NUT
     * @param account Address of the account unlocking their esNUT
     * @param unlockAmount Amount of esNUT to unlock
     */
    function unlock(address account, uint256 unlockAmount) public onlyRole(UNLOCK_ROLE) checkInvariantAfter {
        require(balanceOf(account) >= unlockAmount, "esNUT: Insufficient Balance to unlock");
        _burn(account, unlockAmount);
        nutToken.mint(account, unlockAmount);
    }

    /**
     * @notice Locks NUT to mint equivalent esNUT for the caller
     * @param amount Amount of NUT to lock
     */
    function lock(uint256 amount) public checkInvariantAfter {
        nutToken.burn(msg.sender, amount);
        _mint(msg.sender, amount);
    }

    /**
     * @notice Toggles the token transfer lock
     * @param _tokenLocked Boolean value indicating the desired state
     */
    function setTokenLock(bool _tokenLocked) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenLocked = _tokenLocked;
    }

    /**
     * @notice Transfers a specified amount of any ERC20 token from this contract to a target address.
     * @dev Only callable by addresses with the DEFAULT_ADMIN_ROLE.
     * @param tokenAddress The address of the ERC20 token to be transferred.
     * @param target The address that will receive the ERC20 tokens.
     * @param amount The amount of tokens to be transferred.
     */
    function rescueERC20(address tokenAddress, address target, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ERC20(tokenAddress).safeTransfer(target, amount);
    }


}