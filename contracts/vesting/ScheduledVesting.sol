// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../node_modules/@openzeppelin/contracts/access/AccessControl.sol";
import "../esNUT.sol"; // Assuming you have an esNUT.sol that contains the esNUT contract

contract ScheduledVesting is AccessControl {
    using SafeERC20 for ERC20;
    
    struct VestingSchedule {
        uint256 timestampAvailable;
        uint256 amount;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    mapping(address => VestingSchedule[]) public schedules;

    esNUT private esnutToken;
    NUT private nutToken; // Assuming you have a corresponding NUT token implementation

    event ScheduledUnlock(address indexed account, uint256 amount);

    constructor(address _esnutToken, address _nutToken) {
        esnutToken = esNUT(_esnutToken);
        nutToken = NUT(_nutToken);
        
        _setupRole(ADMIN_ROLE, _msgSender());
    }

    function setSchedule(address account, VestingSchedule[] calldata newSchedule) external onlyRole(ADMIN_ROLE) {
        require(newSchedule.length > 0, "ScheduledVesting: Schedule length must be greater than 0");
                 
        // Check that the schedule is in timestamp-sequential order
        for (uint256 i = 0; i < newSchedule.length - 1; i++) {
            require(newSchedule[i].timestampAvailable < newSchedule[i+1].timestampAvailable, "ScheduledVesting: Schedule timestamps must be in sequential order");
        }
        
        // Check schedule and vest accordingly
        vestTokens(account);
      
        // Clear the current schedule for the account
        delete schedules[account];
   
        // Resize the storage array
        delete schedules[account];
    
        // Manually copy each element
        for (uint256 i = 0; i < newSchedule.length; i++) {
            schedules[account].push( newSchedule[i] );
        }
    }

    function cancelSchedule(address account) external onlyRole(ADMIN_ROLE) {
        require(schedules[account].length > 0, "ScheduledVesting: No schedule set for account");

        // Fulfill existing schedule
        for (uint256 i = 0; i < schedules[account].length; i++) {
            if (block.timestamp >= schedules[account][i].timestampAvailable) {
                esnutToken.unlock(account, schedules[account][i].amount);
            }
        }

        delete schedules[account];
    }

    function vestTokens(address account) public returns (uint256 totalVested) {
        VestingSchedule[] storage userSchedule = schedules[account];
        for (uint256 i = 0; i < userSchedule.length; i++) {
            if (block.timestamp >= userSchedule[i].timestampAvailable && userSchedule[i].amount > 0) {
                totalVested += userSchedule[i].amount;
                userSchedule[i].amount = 0; // Mark as vested
            }
        }
        esnutToken.unlock(msg.sender, totalVested);
        emit ScheduledUnlock(msg.sender, totalVested);
    }

    /// @notice ERC20 rescue
    function rescueERC20(address tokenAddress, address target, uint256 amount) external onlyRole(ADMIN_ROLE) {
        ERC20(tokenAddress).safeTransfer(target, amount);
    }
}
