// SPDX-License-Identifier: none
pragma solidity 0.8.19;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";


/*
  Minter/Burner is the esNUT contract
  This is all tokens are initially esNUT, to be unlocked as NUT after vesting
*/
contract NUT is ERC20PresetMinterPauser, ERC20Capped {
  constructor() 
    ERC20PresetMinterPauser("Thetanuts", "NUT") 
    ERC20Capped(1e28)
  {}
  
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override (ERC20, ERC20PresetMinterPauser) {
    super._beforeTokenTransfer(from, to, amount);
  }

  
  function _mint(address account, uint256 amount) internal override (ERC20, ERC20Capped) {
    super._mint(account, amount);
  }
  
  function burn(address account, uint256 amount) onlyRole(MINTER_ROLE) public {
    _burn(account, amount);
  }
}
