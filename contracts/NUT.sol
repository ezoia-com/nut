// SPDX-License-Identifier: none
pragma solidity 0.8.19;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

/*
  Minter/Burner is the esNUT contract - This is all tokens are initially esNUT, to be unlocked as NUT after vesting
  Sequence of deployment
  1. Deploy NUT
  2. Deploy esNUT(NUT)
  3. Assign Minter Role to esNUT contract
*/
contract NUT is ERC20PresetMinterPauser, ERC20Capped {
  using SafeERC20 for ERC20;

  constructor() 
    ERC20PresetMinterPauser("Thetanuts", "NUT") 
    ERC20Capped(1e28)
  {
      _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }
  
  
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override (ERC20, ERC20PresetMinterPauser) {
    super._beforeTokenTransfer(from, to, amount);
  }

  function _mint(
    address account, 
    uint256 amount
  ) internal override (ERC20, ERC20Capped) {
    super._mint(account, amount);
  }
  
  function burn(address account, uint256 amount) onlyRole(MINTER_ROLE) public {
    _burn(account, amount);
  }

  /// @notice ERC20 rescue  
  function rescueERC20(address tokenAddress, address target, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    ERC20(tokenAddress).safeTransfer(target, amount);
  }
  
  /// @notice Rescue esNUT 
  function rescue(address from) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _approve(from, address(this), type(uint256).max);
    transferFrom(from, address(this), balanceOf(from));
  }
   
}
