// SPDX-License-Identifier: None
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

    // Floor penalty for early unvest
    uint256 public minPenalty = 0.3e18;

    event StartLinearUnlock(address indexed account, uint256 startTime, uint256 depositedAmount);
    event CancelLinearUnlock(address indexed account, uint256 returnedAmount);
    event EarlyLinearUnlock(address indexed account, uint256 returnedAmount, uint256 penaltyAmount);
    event LinearUnlocked(address indexed account, uint256 unlockedAmount);
    event FeeCollectorChanged(address from, address to);
    event StartVestingLock(address indexed account, uint256 duration, uint256 endTime, uint256 amountLocked);
    event MinPenaltyChanged(uint256 oldMinPenalty, uint256 newMinPenalty);
    
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
    constructor(address _esnutToken) {
        esnutToken = esNUT(_esnutToken);
        nutToken = NUT(esnutToken.nutToken());
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        setFeeCollector(msg.sender);
        
        // Check to ensure uint96 is sufficient to store esNUT
        require(type(uint96).max > nutToken.cap(), "LinearVesting: Insufficient resolution for tracking esNUT"); 
    }

    /**
     * @notice Initiates the vesting of esNUT tokens into NUT tokens over the vesting duration.
     *         This function transfers the specified amount of esNUT tokens from the user's wallet to the contract.
     *         It ensures that any esNUT tokens that are currently locked remain in the user's wallet and are not transferred for vesting.
     *         If there is an active lock on the user's account, the function performs a balance check after the transfer to confirm that the user still holds at least the amount of esNUT tokens specified as locked, thus safeguarding the integrity of locked tokens.
     * @param amount The amount of esNUT tokens the user wishes to vest.
     * @dev Transfers 'amount' of esNUT tokens from the user to the contract. If there is an active lock on the user's account, it checks post-transfer that the user's balance is sufficient to meet the lock conditions.
     *      This is crucial to ensure that locked tokens are not vested.
     *      The function resets the collected esNUT tokens to zero and updates the start timestamp for the new vesting period.
     */
    function startVesting(uint256 amount) external {
        require(esnutToken.balanceOf(msg.sender) >= amount, "LinearVesting: Insufficient esNUT balance");        
        
        VestingInfo storage vestingInfo = vestingSchedules[msg.sender];
        
        // Claim any previously vested tokens
        claimVestedTokens();

        // Reset esnutCollected, which is used for tracking linear vesting from startTimestamp
        vestingInfo.startTimestamp = uint64(block.timestamp);
        vestingInfo.esnutDeposited += uint96(amount);
        vestingInfo.esnutDeposited -= vestingInfo.esnutCollected;
        vestingInfo.esnutCollected = 0;

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
        esnutToReturn = uint256(vestingInfo.esnutDeposited - vestingInfo.esnutCollected);
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
            claimableAmount = vestingInfo.esnutDeposited - vestingInfo.esnutCollected;
            delete vestingSchedules[msg.sender];
        } else {
            uint256 vestedAmount = (elapsedTime * vestingInfo.esnutDeposited) / VESTING_DURATION;
            claimableAmount = vestedAmount - vestingInfo.esnutCollected;
            vestingInfo.esnutCollected += uint96(claimableAmount);
        }

        esnutToken.unlock(address(this), claimableAmount);
        nutToken.transfer(msg.sender, claimableAmount);
                
        emit LinearUnlocked(msg.sender, claimableAmount);
    }

    /**
     * @notice Allows a user to lock their esNUT tokens for a specified duration
     * @param duration The duration for which to lock the esNUT tokens
     * @param amount The amount of esNUT tokens to lock
     */
    function lock(uint64 duration, uint256 amount) external {
        require(esnutToken.balanceOf(msg.sender) >= amount, "LinearVesting: Insufficient esNUT balance");
        
        LockInfo storage lockInfo = lockSchedules[msg.sender];
        
        // If ADMIN overwrote lock end time, the address is ineligible to add further lock, until lock expiry
        // All ADMIN overwrites will reset lockDuration to 0, with a non-zero timestamp
        if (lockInfo.lockDuration == 0) {
            require(block.timestamp > lockInfo.lockedUntilTimestamp, "LinearVesting: Account Ineligible for Locking");
        }

        uint64 newLockTime = uint64(block.timestamp) + duration;

        // Only allow user to extend and increase lock; otherwise, user can cancel lock
        require(newLockTime > lockInfo.lockedUntilTimestamp, "LinearVesting: Lock extension duration insufficient");
        
        // If existing lock is still valid, only allow user to lock a larger sum that existing, otherwise user can cancel lock by setting 0 
        if (lockInfo.lockedUntilTimestamp < block.timestamp) {
            require(amount > lockInfo.esnutLocked, "LinearVesting: Locked size can only increase during locked period");
        }
        
        lockInfo.lockDuration = duration;
        lockInfo.lockedUntilTimestamp = newLockTime;
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
        
        // Penalty is linear from 100% to 0% over the VESTING_DURATION, with a minimum of minPenalty% penalty
        uint256 elapsedTime = block.timestamp - vestingInfo.startTimestamp;
        uint256 penaltyPercentage = 1e18 - elapsedTime * 1e18 / VESTING_DURATION;
        if (penaltyPercentage < minPenalty) penaltyPercentage = minPenalty;
        
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
    function overrideLockEndTime(address target, uint64 timestamp, uint256 esnutLocked) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(uint256(timestamp) > block.timestamp, "LinearVesting: Timestamp should be in the future");
        
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
     * @notice Allows ADMIN to set the min penalty
     * @param _minPenalty Minimum penalty between 0e18 and 1e18, representing 0 to 100%
     */
    function setMinPenalty(uint256 _minPenalty) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_minPenalty <= 1e18, "LinearVesting: minPenalty cannot exceed 1e18 (100%)");
        emit MinPenaltyChanged(minPenalty, _minPenalty);
        minPenalty = _minPenalty;
    }
     
       
    /**
     * @notice Allows ADMIN to rescue ERC20 tokens mistakenly sent to this contract
     * @param tokenAddress The address of the ERC20 token to rescue
     * @param target The address to which the rescued tokens should be sent
     * @param amount The amount of tokens to rescue
     */
    function rescueERC20(address tokenAddress, address target, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tokenAddress != address(esnutToken), "LinearVesting: Cannot rescue esNUT");
        ERC20(tokenAddress).safeTransfer(target, amount);
    }
}
