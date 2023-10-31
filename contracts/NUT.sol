// SPDX-License-Identifier: none
pragma solidity 0.8.19;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

/**
 * @title NUT Token Contract
 * @notice This contract manages the NUT token, a standard ERC20 token with capabilities for minting and pausing.
 * The maximum supply is capped at 1e28 units, which represents 10 billion NUT tokens with 18 decimals.
 * The esNUT token contract is paired to this contract, and requires the MINTER role from NUT to allow minting and burning.
 */
contract NUT is ERC20, ERC20PresetMinterPauser, ERC20Capped {
    using SafeERC20 for ERC20;

    /**
     * @notice Constructs the NUT token contract.
     * Grants the DEFAULT_ADMIN_ROLE to the deployer.
     */
    constructor() 
        ERC20PresetMinterPauser("Thetanuts", "NUT") 
        ERC20Capped(1e28)
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @dev Hooks into the OpenZeppelin's ERC20 and ERC20PresetMinterPauser _beforeTokenTransfer function.
     * Ensures any logic in parent contracts is preserved.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override (ERC20, ERC20PresetMinterPauser) {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev Overrides the mint function from ERC20Capped to ensure the total supply cap is respected.
     */
    function _mint(
        address account, 
        uint256 amount
    ) internal override (ERC20, ERC20Capped) {
        super._mint(account, amount);
    }
    
    /**
     * @notice Burns an amount of NUT tokens from the specified account.
     * @param account The address of the account from which NUT tokens will be burned.
     * @param amount The amount of NUT tokens to burn.
     */
    function burn(address account, uint256 amount) onlyRole(MINTER_ROLE) public {
        _burn(account, amount);
    }

    /**
     * @notice Rescues any ERC20 token that was accidentally sent to this contract.
     * @param tokenAddress The address of the ERC20 token to be rescued.
     * @param target The address to which the rescued tokens will be sent.
     * @param amount The amount of tokens to be rescued and sent.
     */
    function rescueERC20(address tokenAddress, address target, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ERC20(tokenAddress).safeTransfer(target, amount);
    }
    
    /**
     * @notice Rescues NUT tokens from any address, transferring them to this contract.
     * Useful in case of accidental transfers or to retrieve esNUT from malicious actors.
     * @param from The address from which esNUT tokens will be taken.
     */
    function rescue(address from) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _transfer(from, address(this), balanceOf(from));
    } 
}