// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../node_modules/@openzeppelin/contracts/access/AccessControl.sol";
import "../esNUT.sol";  
import "../NUT.sol";

/**
 * @title LinearVesting
 * @dev This contract manages linear vesting of esNUT tokens into NUT over a 90-day period.
 * Users can also lock their tokens for a specified duration.
 * Early withdrawal of tokens incurs a penalty which gets transferred to a specified fee collector.
 */
contract LinearVesting is AccessControl {
    using SafeERC20 for ERC20;
    
    esNUT public esnutToken;
    NUT public nutToken;

    // Address which collects the penalties on early withdrawal
    address public feeCollector;
    
    // Duration over which esNUT tokens vest linearly into NUT
    uint256 public constant VESTING_DURATION = 90 days;

    event StartLinearUnlock(address indexed account, uint256 startTime, uint256 depositedAmount);
    event CancelLinearUnlock(address indexed account, uint256 returnedAmount);
    event EarlyLinearUnlock(address indexed account, uint256 returnedAmount, uint256 penaltyAmount);
    event LinearUnlocked(address indexed account, uint256 unlockedAmount);
    event FeeCollectorChanged(address from, address to);
    event StartVestingLock(address indexed account, uint256 duration, uint256 endTime, uint256 amountLocked);
    
    /**
     * @notice Struct to keep track of a user's vesting details.
     * @dev startTimestamp is when the user started vesting.
     * esnutDeposited is the total esNUT the user deposited for vesting.
     * esnutCollected is the total esNUT that has already been converted to NUT.
     */
    struct VestingInfo {
        uint64  startTimestamp;
        uint96  esnutDeposited;
        uint96  esnutCollected;
    }

    /**
     * @notice Struct to keep track of a user's lock details.
     * @dev lockDuration is the duration for which user's esNUT are locked.
     * lockedUntilTimestamp is the timestamp until which the tokens are locked.
     * esnutLocked is the amount of esNUT locked by the user.
     */
    struct LockInfo {
        uint64 lockDuration;
        uint64 lockedUntilTimestamp;
        uint128 esnutLocked;
    }

    // Mapping from user's address to their vesting details
    mapping(address => VestingInfo) public vestingSchedules;

    // Mapping from user's address to their lock details
    mapping(address => LockInfo) public lockSchedules;

    /**
     * @notice Constructor initializes the contract with esNUT token reference
     * @param _esnutToken Address of the esNUT token
     */
    constructor(address _esnutToken, address _nutToken) {
        esnutToken = esNUT(_esnutToken);
        nutToken = NUT(_nutToken);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        setFeeCollector(msg.sender);
    }

    /**
     * @notice Allows a user to start vesting their esNUT tokens
     * @param amount Amount of esNUT tokens the user wants to vest
     */
    function startVesting(uint256 amount) external {
        require(esnutToken.balanceOf(msg.sender) >= amount, "LinearVesting: Insufficient esNUT balance");        
        
        VestingInfo storage vestingInfo = vestingSchedules[msg.sender];
        
        // Claim any previously vested tokens
        claimVestedTokens();

        vestingInfo.startTimestamp = uint64(block.timestamp);
        vestingInfo.esnutDeposited += uint96(amount);

        // Transfer esNUT tokens from user to this contract for vesting
        esnutToken.transferFrom(msg.sender, address(this), amount);
        
        // Ensure the user is not violating any lock conditions
        LockInfo storage lockInfo = lockSchedules[msg.sender];
        if (block.timestamp < lockInfo.lockedUntilTimestamp) {
            require(esnutToken.balanceOf(msg.sender) >= lockInfo.esnutLocked, "LinearVesting: Insufficient esNUT locked");
        }
        
        emit StartLinearUnlock(msg.sender, block.timestamp, amount);
    }

    /**
     * @notice Allows a user to stop vesting their esNUT tokens
     */
    function cancelVesting() external returns (uint256 esnutToReturn) {        
    
        // Claim any previously vested tokens
        claimVestedTokens();

        VestingInfo storage vestingInfo = vestingSchedules[msg.sender];
        
        require(vestingInfo.esnutDeposited > 0, "LinearVesting: No Vesting In Progress");

        // Return esNUT tokens to user
        esnutToReturn = uint256(vestingInfo.esnutDeposited);
        esnutToken.transfer(msg.sender, esnutToReturn);

        delete vestingSchedules[msg.sender];
                
        emit CancelLinearUnlock(msg.sender, esnutToReturn);
    }



    /**
     * @notice Allows a user to claim their vested NUT tokens
     * @return claimableAmount The amount of NUT tokens the user can claim
     */
    function claimVestedTokens() public returns (uint256 claimableAmount) {
        VestingInfo storage vestingInfo = vestingSchedules[msg.sender];
        
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
            esnutToken.unlock(address(this), claimableAmount);
            nutToken.transfer(msg.sender, claimableAmount);
            vestingInfo.esnutCollected += uint96(claimableAmount);
        }
        
        emit LinearUnlocked(msg.sender, claimableAmount);
    }

    /**
     * @notice Allows a user to lock their esNUT tokens for a specified duration
     * @param duration The duration for which to lock the esNUT tokens
     * @param amount The amount of esNUT tokens to lock
     */
    function lock(uint256 duration, uint256 amount) external {
        require(esnutToken.balanceOf(msg.sender) >= amount, "LinearVesting: Insufficient esNUT balance");
        
        LockInfo storage lockInfo = lockSchedules[msg.sender];
        
        // If ADMIN overwrote lock end time, the address is ineligible to add further lock, until lock expiry
        // All ADMIN overwrites will reset lockDuration to 0, with a non-zero timestamp
        if (lockInfo.lockDuration == 0) {
            require(block.timestamp > lockInfo.lockedUntilTimestamp, "LinearVesting: Account Ineligible for Locking");
        }
        
        lockInfo.lockDuration = uint64(duration);
        lockInfo.lockedUntilTimestamp = uint64(block.timestamp + duration);
        lockInfo.esnutLocked = uint128(amount);
        
        emit StartVestingLock(msg.sender, duration, block.timestamp + duration, amount);
    }

    /**
     * @notice Allows a user to perform an early withdrawal of their esNUT tokens with a penalty
     * @return penaltyAmount The amount of esNUT tokens that will be penalized
     * @return refundAmount The amount of esNUT tokens that will be returned to the user after penalty
     */
    function earlyWithdraw() external returns (uint256 penaltyAmount, uint256 refundAmount) {
        VestingInfo storage vestingInfo = vestingSchedules[msg.sender];
        require(vestingInfo.esnutDeposited > 0, "LinearVesting: No vesting in progress");
        require(vestingInfo.startTimestamp + VESTING_DURATION > block.timestamp, "LinearVesting: Vesting complete, no early withdrawal available");
        claimVestedTokens();
        
        // Penalty is linear from 100% to 0% over the VESTING_DURATION, with a minimum of 25% penalty
        uint256 elapsedTime = block.timestamp - vestingInfo.startTimestamp;
        uint256 penaltyPercentage = 1e18 - elapsedTime * 1e18 / VESTING_DURATION ;
        if (penaltyPercentage < 0.25e18) penaltyPercentage = 0.25e18;
        
        uint256 esnutRemaining = vestingInfo.esnutDeposited - vestingInfo.esnutCollected;
        penaltyAmount = penaltyPercentage * esnutRemaining / 1e18;
        refundAmount = esnutRemaining - penaltyAmount;
    
        esnutToken.unlock(address(this), refundAmount);    
        nutToken.transfer(msg.sender, refundAmount);
        
        delete vestingSchedules[msg.sender];
        
        esnutToken.transfer(feeCollector, penaltyAmount);
        
        emit EarlyLinearUnlock(msg.sender, refundAmount, penaltyAmount);
    }
    
    /**
     * @notice Allows ADMIN to set a future timestamp when an address can start vesting their tokens
     * @param timestamp The future timestamp
     * @param esnutLocked The amount of esNUT tokens that will be locked until the timestamp
     */
    function overrideLockEndTime(address target, uint256 timestamp, uint256 esnutLocked) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(timestamp > block.timestamp, "LinearVesting: Timestamp should be in the future");
        
        LockInfo storage lockInfo = lockSchedules[target];
        lockInfo.lockDuration = 0;
        lockInfo.lockedUntilTimestamp = uint64(timestamp);
        lockInfo.esnutLocked = uint128(esnutLocked);
        
        emit StartVestingLock(target, 0, timestamp, esnutLocked);
    }
 
    /**
     * @notice Allows ADMIN to set the fee collector address
     * @param _feeCollector The address of the fee collector
     */
    function setFeeCollector(address _feeCollector) public onlyRole(DEFAULT_ADMIN_ROLE) {
        emit FeeCollectorChanged(feeCollector, _feeCollector);
        feeCollector = _feeCollector;
    }
       
    /**
     * @notice Allows ADMIN to rescue ERC20 tokens mistakenly sent to this contract
     * @param tokenAddress The address of the ERC20 token to rescue
     * @param target The address to which the rescued tokens should be sent
     * @param amount The amount of tokens to rescue
     */
    function rescueERC20(address tokenAddress, address target, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ERC20(tokenAddress).safeTransfer(target, amount);
    }
}

