// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../node_modules/@openzeppelin/contracts/access/AccessControl.sol";
import "../esNUT.sol"; // Assuming you have an esNUT.sol that contains the esNUT contract

contract LinearVesting is AccessControl {
    using SafeERC20 for ERC20;
    
    esNUT public esnutToken;
    address public feeCollector;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public constant VESTING_DURATION = 90 days;

    struct VestingInfo {
        uint64  startTimestamp;
        uint96  esnutDeposited;
        uint96  esnutCollected;
    }

    struct LockInfo {
        uint64 lockDuration;  
        uint64 lockedUntilTimestamp;
        uint128 esnutLocked;
    }

    mapping(address => VestingInfo) public vestingSchedules;
    mapping(address => LockInfo) public lockSchedules;

    constructor(address _esnutToken, address _nutToken) {
        esnutToken = esNUT(_esnutToken);
        feeCollector = msg.sender;
    }

    function startVesting(uint256 amount) external {
        require(esnutToken.balanceOf(msg.sender) >= amount, "LinearVesting: Insufficient esNUT balance");        
        
        VestingInfo storage vestingInfo = vestingSchedules[msg.sender];
        
        claimVestedTokens();

        vestingInfo.startTimestamp = uint64(block.timestamp);
        vestingInfo.esnutDeposited += uint96(amount);

        // esnut is transferred into the contract 
        esnutToken.transferFrom(msg.sender, address(this), amount);
        
        // Locked amount cannot start vesting. Check if Lock violated after the esNUT is transferred. 
        LockInfo storage lockInfo = lockSchedules[msg.sender];
        if (block.timestamp < lockInfo.lockedUntilTimestamp) {
          require(esnutToken.balanceOf(msg.sender) >= lockInfo.esnutLocked, "LinearVesting: Insufficient esNUT locked");
        }
    }

    function claimVestedTokens() public returns (uint256 claimableAmount) {
        VestingInfo storage vestingInfo = vestingSchedules[msg.sender];
        
        // No vesting in progress, return
        if (vestingInfo.esnutDeposited == 0) {
          return 0;
        }

        uint256 elapsedTime = block.timestamp - vestingInfo.startTimestamp;
        if (elapsedTime >= VESTING_DURATION) {
            esnutToken.unlock(msg.sender, vestingInfo.esnutDeposited - vestingInfo.esnutCollected);
            delete vestingSchedules[msg.sender];
        } else {
            uint256 vestedAmount = (elapsedTime * vestingInfo.esnutDeposited) / VESTING_DURATION;
            claimableAmount = vestedAmount - vestingInfo.esnutCollected;
            esnutToken.unlock(msg.sender, claimableAmount);
            vestingInfo.esnutCollected += uint96(claimableAmount);
        }
    }

    function lock(uint256 duration, uint256 amount) external {
        require(esnutToken.balanceOf(msg.sender) >= amount, "LinearVesting: Insufficient esNUT balance");

        LockInfo storage lockInfo = lockSchedules[msg.sender];
        lockInfo.lockDuration = uint64(duration);
        lockInfo.lockedUntilTimestamp = uint64(block.timestamp + duration);
        lockInfo.esnutLocked = uint128(amount);
    }
    
    function earlyWithdraw() external returns (uint256 penaltyAmount, uint256 refundAmount) {
        VestingInfo storage vestingInfo = vestingSchedules[msg.sender];
        require(vestingInfo.esnutDeposited > 0, "LinearVesting: No vesting in progress");
    
        // First claim all vested tokens
        claimVestedTokens();
        
        // Penalty is linear from 100% to 0% over the VESTING_DURATION, with a minimum of 25% penalty
        uint256 elapsedTime = block.timestamp - vestingInfo.startTimestamp;
        uint256 penaltyPercentage = 1e18 - elapsedTime * 1e18 / VESTING_DURATION ;
        if (penaltyPercentage < 0.25e18) penaltyPercentage = 0.25e18;
        
        uint256 esnutRemaining = vestingInfo.esnutDeposited - vestingInfo.esnutCollected;
        penaltyAmount = penaltyPercentage * esnutRemaining / 1e18;
        refundAmount = esnutRemaining - penaltyAmount;
    
        // Transfer penalty to feeCollector
        esnutToken.transfer(feeCollector, penaltyAmount);
    
        // Refund the remaining amount to the user
        esnutToken.unlock(msg.sender, refundAmount);
    
        // Clear the vesting schedule for the user
        delete vestingSchedules[msg.sender];
    }
    
    function overrideLockEndTime(uint256 timestamp, uint256 esnutLocked) external onlyRole(ADMIN_ROLE) {
        require(timestamp > block.timestamp, "LinearVesting: Timestamp should be in the future");
        
        LockInfo storage lockInfo = lockSchedules[msg.sender];
        lockInfo.lockDuration = 0;
        lockInfo.lockedUntilTimestamp = uint64(timestamp);
        lockInfo.esnutLocked = uint128(esnutLocked);
    }
 
    function setFeeCollector(address _feeCollector) external onlyRole(ADMIN_ROLE) {
        feeCollector = _feeCollector;
    }
       
    /// @notice ERC20 rescue
    function rescueERC20(address tokenAddress, address target, uint256 amount) external onlyRole(ADMIN_ROLE) {
        ERC20(tokenAddress).safeTransfer(target, amount);
    }
}