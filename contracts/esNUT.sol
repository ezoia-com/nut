// SPDX-License-Identifier: none
pragma solidity 0.8.19;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "../node_modules/@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./NUT.sol";

contract esNUT is ERC20, ERC20Permit, ERC20Votes, AccessControlEnumerable {
  NUT private immutable nutToken;
  bool public tokenLocked; 
 
  /// @notice Access role for addresses who are allowed to receive/transfer esNUT 
  bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

  /// @notice Access role for addresses who are allowed to unlock esNUT 
  bytes32 public constant UNLOCK_ROLE   = keccak256("UNLOCK_ROLE");

  constructor(address _nutToken)
    ERC20("NUT Governance Token", "esNUT")
    ERC20Permit("NUT Governance Token")
  {
    nutToken = NUT(_nutToken);
    tokenLocked = true;

    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(TRANSFER_ROLE, _msgSender());
    _setupRole(MINTER_ROLE, _msgSender());
  }

  // The functions below are overrides required by Solidity.
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
  
  /// @notice Restrict transfer and keep track of balance changes in the rewardTracker
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
    // check only regular transfers, from/to 0x0 are burn/mint and are unavailable/restricted, and only if tokenLocked
    if (from != address(0) && to != address(0) && tokenLocked) _checkRole(TRANSFER_ROLE);
    // if NUT token is paused, esNUT should be paused too
    require( nutToken.paused() == false, "Paused" );
  }
  
  modifier checkInvariantAfter {
    _;
    require(nutToken.totalSupply() + totalSupply() <= nutToken.cap(), "esNUT: NUT + esNUT invariant breached");
  }
  
  /// @notice Unlock token
  function unlock(address account, uint unlockAmount) public onlyRole(UNLOCK_ROLE) checkInvariantAfter {
    require(balanceOf(account) >= unlockAmount, "esNUT: Insufficient Balance to unlock");
    _burn(account, unlockAmount);
    nutToken.mint(account, unlockAmount);
  }
 
  /// @notice Lock token
  function lock(uint256 amount) public checkInvariantAfter {
    nutToken.burn(msg.sender, amount);
    _mint(msg.sender, amount);
  }

  /// @notice Set Token Transferability
  function setTokenLock(bool _tokenLocked) external onlyRole(DEFAULT_ADMIN_ROLE) {
    tokenLocked = _tokenLocked;
  }
}
