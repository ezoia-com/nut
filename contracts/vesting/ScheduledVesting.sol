// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../node_modules/@openzeppelin/contracts/access/AccessControl.sol";
import "../esNUT.sol";

/**
 * @title ScheduledVesting
 * @dev This contract handles the vesting schedules for esNUT tokens.
 * @notice Users with a vesting schedule can claim their vested esNUT tokens based on predetermined schedules.
 */
contract ScheduledVesting is AccessControl {
    using SafeERC20 for ERC20;
    
    /// @dev Struct for holding the vesting schedule for a user.
    struct VestingSchedule {
        uint256 timestampAvailable;  // Timestamp when the tokens become available
        uint256 amount;              // Amount of tokens to unlock
    }
    mapping(address => VestingSchedule[]) public schedules;

    esNUT public esnutToken;

    event ScheduledUnlock(address indexed account, uint256 amount);

    /**
     * @dev Constructor to set the initial configuration.
     * @param _esnutToken Address of the esNUT token contract.
     */
    constructor(address _esnutToken) {
        esnutToken = esNUT(_esnutToken);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Sets the vesting schedule for a given account.
     * @dev Can only be called by an account with the DEFAULT_ADMIN_ROLE.
     * @param account Address of the user.
     * @param newSchedule Array of VestingSchedule struct detailing the vesting schedule.
     */
    function setSchedule(address account, VestingSchedule[] calldata newSchedule) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newSchedule.length > 0, "ScheduledVesting: Schedule length must be greater than 0");
                 
        // Check that the schedule is in timestamp-sequential order
        for (uint256 i = 0; i < newSchedule.length - 1; i++) {
            require(newSchedule[i].timestampAvailable < newSchedule[i+1].timestampAvailable, "ScheduledVesting: Schedule timestamps must be in sequential order");
        }
        
        // Vest tokens according to existing schedule before updating
        vestTokens(account);
      
        // Clear and update the schedule
        delete schedules[account];
        for (uint256 i = 0; i < newSchedule.length; i++) {
            schedules[account].push(newSchedule[i]);
        }
    }

    /**
     * @notice Cancels the vesting schedule for a given account and immediately unlocks any vested tokens.
     * @dev Can only be called by an account with the ADMIN_ROLE.
     * @param account Address of the user.
     */
    function cancelSchedule(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(schedules[account].length > 0, "ScheduledVesting: No schedule set for account");

        // Fulfill existing schedule
        for (uint256 i = 0; i < schedules[account].length; i++) {
            if (block.timestamp >= schedules[account][i].timestampAvailable) {
                esnutToken.unlock(account, schedules[account][i].amount);
            }
        }

        delete schedules[account];
    }

    /**
     * @notice Allows a user to claim their vested tokens based on their schedule.
     * @param account Address of the user.
     * @return totalVested The total number of tokens that were vested.
     */
    function vestTokens(address account) public returns (uint256 totalVested) {
        VestingSchedule[] storage userSchedule = schedules[account];
        for (uint256 i = 0; i < userSchedule.length; i++) {
            if (block.timestamp >= userSchedule[i].timestampAvailable && userSchedule[i].amount > 0) {
                totalVested += userSchedule[i].amount;
                userSchedule[i].amount = 0; // Mark as vested
            }
        }
        if (totalVested > 0) {
          esnutToken.unlock(account, totalVested);
          emit ScheduledUnlock(account, totalVested);
        }
    }

    /**
     * @notice Allows the ADMIN_ROLE to rescue any ERC20 tokens sent to the contract by mistake.
     * @param tokenAddress Address of the token contract.
     * @param target Address to send the tokens to.
     * @param amount Amount of tokens to send.
     */
    function rescueERC20(address tokenAddress, address target, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ERC20(tokenAddress).safeTransfer(target, amount);
    }
}
