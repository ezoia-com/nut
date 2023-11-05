import brownie
import pytest
import math
from brownie import NUT, esNUT, accounts, ScheduledVesting, LinearVesting, chain, history

@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

def test_deployment():
    # Initial deployment of the NUT contract
    nut = NUT.deploy({'from': accounts[0]})
    assert nut.totalSupply() == 0, "Initial NUT supply is not 0"
    assert nut.cap() == 1e28, "NUT cap is not 1e28"
    assert nut.paused() == False, "NUT contract is paused upon deployment"
    assert nut.hasRole(nut.DEFAULT_ADMIN_ROLE(), accounts[0]), "Deployer doesn't have DEFAULT_ADMIN_ROLE in NUT"
    
    # Initial deployment of the esNUT contract
    esnut = esNUT.deploy(nut.address, {'from': accounts[0]})
    assert esnut.totalSupply() == 1e28, "Initial esNUT supply is not 1e28"
    assert esnut.tokenLocked() == True, "esNUT transfers are not locked upon deployment"
    assert esnut.hasRole(esnut.DEFAULT_ADMIN_ROLE(), accounts[0]), "Deployer doesn't have DEFAULT_ADMIN_ROLE in esNUT"
    
    # Verify the relationship between NUT and esNUT
    assert esnut.nutToken() == nut.address, "esNUT's reference to NUT token is incorrect"

    # Setup MINTER role for esnut
    nut.grantRole(nut.MINTER_ROLE(), esnut.address)
    
    # Ensure that esNUT has the MINTER_ROLE in NUT
    assert nut.hasRole(nut.MINTER_ROLE(), esnut.address), "esNUT doesn't have MINTER_ROLE in NUT"

def test_nut_basic_functionality():
    # Deploy the NUT contract
    nut = NUT.deploy({'from': accounts[0]})
    
    # Minting
    mint_amount = 1e26  # 100 NUT tokens
    nut.mint(accounts[1], mint_amount, {'from': accounts[0]})  # assuming only DEFAULT_ADMIN_ROLE can mint initially
    assert nut.balanceOf(accounts[1]) == mint_amount, "Minting failed for accounts[1]"
    
    # Test minting beyond the cap - should fail
    excessive_mint = 1e28 + 1e26  # exceeds the cap
    with brownie.reverts("ERC20Capped: cap exceeded"):
        nut.mint(accounts[1], excessive_mint, {'from': accounts[0]})
    
    # Pausing
    nut.pause({'from': accounts[0]})
    assert nut.paused() == True, "Failed to pause NUT contract"
    
    # Test transfer while paused - should fail
    with brownie.reverts("ERC20Pausable: token transfer while paused"):
        nut.transfer(accounts[2], 1e25, {'from': accounts[1]})
    
    # Unpausing and testing ERC20 behavior
    nut.unpause({'from': accounts[0]})
    assert nut.paused() == False, "Failed to unpause NUT contract"

    # Regular transfer
    transfer_amount = 5e25  # 50 NUT tokens
    nut.transfer(accounts[2], transfer_amount, {'from': accounts[1]})
    assert nut.balanceOf(accounts[2]) == transfer_amount, "Transfer failed for accounts[2]"

    # Approval and transferFrom
    approve_amount = 3e25  # 30 NUT tokens
    nut.approve(accounts[3], approve_amount, {'from': accounts[2]})
    assert nut.allowance(accounts[2], accounts[3]) == approve_amount, "Approval failed for accounts[3]"
    
    transfer_from_amount = 2e25  # 20 NUT tokens
    nut.transferFrom(accounts[2], accounts[3], transfer_from_amount, {'from': accounts[3]})
    assert nut.balanceOf(accounts[3]) == transfer_from_amount, "transferFrom failed for accounts[3]"


def test_esnut_basic_functionality():
    # Deploy the NUT and esNUT contracts
    nut = NUT.deploy({'from': accounts[0]})
    esnut = esNUT.deploy(nut.address, {'from': accounts[0]})
    nut.grantRole(nut.MINTER_ROLE(), esnut, {"from": accounts[0]})
    
    # Distribute some esNUT to accounts[1]
    initial_esnut = 1e26  # 100 esNUT tokens
    esnut.transfer(accounts[1], initial_esnut, {'from': accounts[0]})
    assert esnut.balanceOf(accounts[1]) == initial_esnut, "Transfer of esNUT to accounts[1] failed"
    
    # Assign UNLOCK role to accounts[0] to allow unlock
    esnut.grantRole(esnut.UNLOCK_ROLE(), accounts[0], {"from": accounts[0]})
    
    # Unlocking: Convert esNUT to NUT for accounts[1]
    esnut.unlock(accounts[1], initial_esnut / 2, {'from': accounts[0]})  # unlock 50 NUT worth of esNUT
    assert esnut.balanceOf(accounts[1]) == initial_esnut / 2, "Unlocking esNUT to get NUT failed for accounts[1]"
    assert nut.balanceOf(accounts[1]) == initial_esnut / 2, "NUT balance after unlocking is incorrect for accounts[1]"
    
    # Transfer restrictions: Initially, transfers are restricted
    with brownie.reverts("esNUT: Neither sender nor recipient has TRANSFER_ROLE"):
        esnut.transfer(accounts[2], 1e25, {'from': accounts[1]})  # try to transfer 10 esNUT tokens
        
    # Enable transfers by DEFAULT_ADMIN_ROLE
    esnut.setTokenLock(False, {'from': accounts[0]})
    esnut.transfer(accounts[2], 1e25, {'from': accounts[1]})
    assert esnut.balanceOf(accounts[2]) == 1e25, "Transfer of esNUT failed for accounts[2]"
    
    # Invariant check: esNUT.totalSupply() + NUT.totalSupply() = 1e28
    total_esnut = esnut.totalSupply()
    total_nut = nut.totalSupply()
    assert total_esnut + total_nut == 1e28, "Invariant check failed for esNUT and NUT total supplies"


def test_emergency_pause():
    # Deploy the NUT and esNUT contracts
    nut = NUT.deploy({'from': accounts[0]})
    esnut = esNUT.deploy(nut.address, {'from': accounts[0]})
    nut.grantRole(nut.MINTER_ROLE(), esnut, {"from": accounts[0]})
    
    # Grant PAUSER role to a specific account for simulation purposes
    pauser_account = accounts[1]
    nut.grantRole(nut.PAUSER_ROLE(), pauser_account, {"from": accounts[0]})
    
    # Ensure the pauser_account has the PAUSER role for NUT
    assert nut.hasRole(nut.PAUSER_ROLE(), pauser_account), "pauser_account doesn't have PAUSER_ROLE in NUT"
    
    # Distribute some esNUT to accounts[1] and accounts[3] from the deployer (accounts[0])
    initial_esnut = 1e26  # 100 esNUT tokens
    esnut.transfer(accounts[1], initial_esnut, {'from': accounts[0]})
    esnut.transfer(accounts[3], initial_esnut, {'from': accounts[0]})
    
    # Assign UNLOCK role to accounts[0] to allow unlock
    esnut.grantRole(esnut.UNLOCK_ROLE(), accounts[0], {"from": accounts[0]})
    
    # Unlock esNUT to NUT for accounts[0] to facilitate testing
    esnut.unlock(accounts[0], initial_esnut, {'from': accounts[0]})
    
    # Pause the NUT contract using pauser_account
    nut.pause({'from': pauser_account})
    
    # Confirm that the NUT contract is paused
    assert nut.paused(), "NUT contract was not paused"
    
    # Ensure no transfers can happen in the paused state for both NUT and esNUT
    with brownie.reverts("ERC20Pausable: token transfer while paused"):
        nut.transfer(accounts[3], 1e25, {'from': accounts[0]})

    # Assign TRANSFER role to accounts[1] to allow transfer
    esnut.grantRole(esnut.TRANSFER_ROLE(), accounts[1], {"from": accounts[0]})
        
    with brownie.reverts("Paused"):  # As esNUT should be indirectly paused because of NUT
        esnut.transfer(accounts[3], 1e25, {'from': accounts[1]})
    
    # Unpause the NUT contract
    nut.unpause({'from': pauser_account})
    
    # Confirm that the NUT contract is unpaused
    assert not nut.paused(), "NUT contract was not unpaused"
    
    # Ensure transfers can happen in the unpaused state for both NUT and esNUT
    transfer_amount = 1e25  # 10 NUT tokens
    nut.transfer(accounts[3], transfer_amount, {'from': accounts[0]})
    assert nut.balanceOf(accounts[3]) == transfer_amount , "Transfer failed for accounts[3] in NUT"
    
    esnut.transfer(accounts[3], transfer_amount, {'from': accounts[1]})
    assert esnut.balanceOf(accounts[3]) == initial_esnut + transfer_amount, "Transfer failed for accounts[3] in esNUT"
    
    # DEFAULT_ADMIN_ROLE should be able to unpause even if rogue PAUSER pauses
    nut.pause({'from': pauser_account})
    nut.unpause({'from': accounts[0]})
    
    # DEFAULT_ADMIN_ROLE should be able to rescind PAUSER role
    nut.revokeRole(nut.PAUSER_ROLE(), pauser_account, {'from': accounts[0]})
    assert not nut.hasRole(nut.PAUSER_ROLE(), pauser_account), "pauser_account still has PAUSER_ROLE in NUT after revocation"

def test_scheduled_vesting():
    # Deploy the NUT and esNUT contracts
    nut = NUT.deploy({'from': accounts[0]})
    esnut = esNUT.deploy(nut.address, {'from': accounts[0]})
    nut.grantRole(nut.MINTER_ROLE(), esnut, {"from": accounts[0]})

    scheduled_vesting = ScheduledVesting.deploy(esnut.address, {'from': accounts[0]})
    
    # Grant UNLOCK role to scheduled_vesting
    esnut.grantRole(esnut.UNLOCK_ROLE(), scheduled_vesting, {"from": accounts[0]})
    
    # Cover case where schedule is missing
    with brownie.reverts("ScheduledVesting: Schedule length must be greater than 0"):
        scheduled_vesting.setSchedule(accounts[1], [])
        
    # Set a vesting schedule for accounts[1]
    schedule = [
        (brownie.chain.time() + 60 * 60 * 24, 1e25),
        (brownie.chain.time() + 60 * 60 * 48, 1e25)
    ]
    scheduled_vesting.setSchedule(accounts[1], schedule, {'from': accounts[0]})
    
    # Fund scheduled_vesting users
    esnut.transfer(accounts[1], sum( i[1] for i in schedule ), {"from": accounts[0]})
    
    # Verify the vesting schedule is stored correctly
    for i, (timestamp, amount) in enumerate(schedule):
        stored_timestamp, stored_amount = scheduled_vesting.schedules(accounts[1], i)
        assert stored_timestamp == timestamp
        assert stored_amount == amount
        
    # Ensure no tokens can be vested before the first timestamp
    nutBalance = nut.balanceOf(accounts[1])
    scheduled_vesting.vestTokens(accounts[1])
    assert(nut.balanceOf(accounts[1]) == nutBalance, "NUT vested when none expected")
        
    # Advance time and vest tokens at each timestamp
    for timestamp, amount in schedule:
        brownie.chain.sleep(timestamp - brownie.chain.time() + 1)
        prevBalance = nut.balanceOf(accounts[1])
        scheduled_vesting.vestTokens(accounts[1])
        assert nut.balanceOf(accounts[1]) - prevBalance == amount  # Check vested esNUT is unlocked back to user as NUT

        # Modifying a Vesting Schedule
    # Set a new vesting schedule for accounts[1]
    modified_schedule = [
        (brownie.chain.time() + 60 * 60 * 24 * 3, 2e25),  # 3 days from now
        (brownie.chain.time() + 60 * 60 * 24 * 6, 2e25)   # 6 days from now
    ]

    # Before setting a new schedule, we need to fund accounts[1] with the total esNUT for the modified schedule
    esnut.transfer(accounts[1], sum(i[1] for i in modified_schedule), {"from": accounts[0]})

    # Set the modified schedule
    scheduled_vesting.setSchedule(accounts[1], modified_schedule, {'from': accounts[0]})

    # Verify the modified vesting schedule is stored correctly
    for i, (timestamp, amount) in enumerate(modified_schedule):
        stored_timestamp, stored_amount = scheduled_vesting.schedules(accounts[1], i)
        assert stored_timestamp == timestamp
        assert stored_amount == amount

    # Ensure tokens are vested according to the modified schedule
    for timestamp, amount in modified_schedule:
        brownie.chain.sleep(timestamp - brownie.chain.time() + 1)
        prevBalance = nut.balanceOf(accounts[1])
        scheduled_vesting.vestTokens(accounts[1])
        assert nut.balanceOf(accounts[1]) - prevBalance == amount

    # Cancelling a Vesting Schedule
    # Set a new vesting schedule for accounts[2]
    cancel_schedule = [
        (brownie.chain.time() + 60 * 60 * 24 * 4, 3e25),  # 4 days from now
        (brownie.chain.time() + 60 * 60 * 24 * 8, 3e25)   # 8 days from now
    ]

    # Fund accounts[2] with the total esNUT for the cancel_schedule
    esnut.transfer(accounts[2], sum(i[1] for i in cancel_schedule), {"from": accounts[0]})
    scheduled_vesting.setSchedule(accounts[2], cancel_schedule, {'from': accounts[0]})

    # Cancel the schedule
    scheduled_vesting.cancelSchedule(accounts[2], {"from": accounts[0]})
    
    # Ensure no more tokens can be vested for accounts[2], even when time passed
    brownie.chain.sleep( 60 * 60 * 4 * 8 )
    
    with brownie.reverts():
      stored_timestamp, stored_amount = scheduled_vesting.schedules(accounts[2], 0)
      print(stored_timestamp, stored_amount)
      
    prevBalance = nut.balanceOf(accounts[2])
    scheduled_vesting.vestTokens(accounts[2])
    assert nut.balanceOf(accounts[2]) == prevBalance

def test_linear_vesting():
    # Deploy the NUT and esNUT contracts
    nut = NUT.deploy({'from': accounts[0]})
    esnut = esNUT.deploy(nut.address, {'from': accounts[0]})
    nut.grantRole(nut.MINTER_ROLE(), esnut, {"from": accounts[0]})
    
    linear_vesting = LinearVesting.deploy(esnut.address, nut.address, {'from': accounts[0]})
    
    # Grant TRANSFER, UNLOCK role to linear_vesting
    esnut.grantRole(esnut.UNLOCK_ROLE(), linear_vesting, {"from": accounts[0]})
    esnut.grantRole(esnut.TRANSFER_ROLE(), linear_vesting, {"from": accounts[0]})

    # Seed accounts[1]    
    initial_esnut = 1e26
    esnut.transfer(accounts[1], initial_esnut)

    # Set feeCollector
    linear_vesting.setFeeCollector(accounts[9])

    # Start a vesting schedule for accounts[1]
    esnut.approve(linear_vesting, initial_esnut, {'from': accounts[1]})
    linear_vesting.startVesting(initial_esnut, {'from': accounts[1]})
    
    # Claim after 45 days and verify
    brownie.chain.sleep(60 * 60 * 24 * 45)
    claimable = initial_esnut / 2
    linear_vesting.claimVestedTokens({'from': accounts[1]})
    assert nut.balanceOf(accounts[1]) >= claimable
    assert esnut.balanceOf(linear_vesting) + nut.balanceOf(accounts[1]) == initial_esnut 
    
    # Early Withdrawal after 60 days (15 days after the first claim)
    # This will be a total of 60 days into the vesting period.
    brownie.chain.sleep(60 * 60 * 24 * 15)
    expected_penalty_percentage = 1e18 - ( (brownie.chain.time() - linear_vesting.vestingSchedules(accounts[1])[0])  * 1e18 / (90 * 60 * 60 * 24))
    if expected_penalty_percentage < 0.25e18: expected_penalty_percentage = 0.25e18
    
    chain.mine()
    additionalClaimable = linear_vesting.claimVestedTokens.call({"from": accounts[1]})
    expected_penalty = (initial_esnut - claimable - additionalClaimable ) * expected_penalty_percentage / 1e18
    expected_refund = initial_esnut - claimable - additionalClaimable - expected_penalty
    
    linear_vesting.earlyWithdraw({'from': accounts[1]})
    penalty = history[-1].events["Transfer"][-1]["value"]
    refund  = history[-1].events["Transfer"][-2]["value"]
     
    tolerance = 0.0001  # 0.01% tolerance, due to time passing slightly affecting penalty percentages and vesting numbers 
    assert math.isclose(penalty, expected_penalty, rel_tol=tolerance), f"Expected penalty: {expected_penalty}, got: {penalty}"
    assert math.isclose(refund, expected_refund, rel_tol=tolerance), f"Expected refund: {expected_refund}, got: {refund}"
    assert math.isclose(nut.balanceOf(accounts[1]), claimable + refund + additionalClaimable, rel_tol=tolerance)
    assert math.isclose(esnut.balanceOf(linear_vesting.feeCollector()), expected_penalty, rel_tol=tolerance)
    
    # Locking behavior: Lock tokens and ensure they cannot be used in the linear vesting process
    esnut.transfer(accounts[2], 1e26, {'from': accounts[0]})  # Transfer esNUT to accounts[2]
    esnut.approve(linear_vesting, 1e26, {'from': accounts[2]})
    lock_duration = 60 * 60 * 24 * 15  # 15 days
    linear_vesting.lock(lock_duration, 0.5e26, {'from': accounts[2]})  # Lock 50 esNUT for 15 days

    # Trying to start vesting immediately should fail due to the lock
    with brownie.reverts("LinearVesting: Insufficient esNUT locked"): 
      linear_vesting.startVesting(1e26, {'from': accounts[2]})
     
    # Sleep for 10 days and try again. It should still fail.
    brownie.chain.sleep(60 * 60 * 24 * 10)
    with brownie.reverts("LinearVesting: Insufficient esNUT locked"):
        linear_vesting.startVesting(1e26, {'from': accounts[2]})
    
    # Sleep for 5 more days, making it 15 days in total. Vesting should now succeed.
    brownie.chain.sleep(60 * 60 * 24 * 5)
    linear_vesting.startVesting(1e26, {'from': accounts[2]})
    assert esnut.balanceOf(linear_vesting) == 1e26
    
    # Fund accounts[1]
    esnut.transfer(accounts[1], 1e20, {"from": accounts[0]})
    
    # Create a lock for accounts[1]
    linear_vesting.lock(1e6, 1e20, {'from': accounts[1]})

    # Override the lock end time
    future_timestamp = brownie.chain.time() + 1e6
    linear_vesting.overrideLockEndTime(accounts[1], future_timestamp, 1e20, {'from': accounts[0]})
    
    lock_info = linear_vesting.lockSchedules(accounts[1])
    assert lock_info[1] == future_timestamp, "Lock end time override failed"
    
def test_scheduled_vesting_non_sequential_schedule():
    # Deploy the NUT and esNUT contracts
    nut = NUT.deploy({'from': accounts[0]})
    esnut = esNUT.deploy(nut.address, {'from': accounts[0]})
    nut.grantRole(nut.MINTER_ROLE(), esnut, {"from": accounts[0]})

    scheduled_vesting = ScheduledVesting.deploy(esnut.address, {'from': accounts[0]})

    # Try to set a non-sequential schedule for accounts[1]
    non_sequential_schedule = [
        (brownie.chain.time() + 60 * 60 * 48, 1e25),  # 2 days from now
        (brownie.chain.time() + 60 * 60 * 24, 1e25)   # 1 day from now (out of order)
    ]

    with brownie.reverts("ScheduledVesting: Schedule timestamps must be in sequential order"):
        scheduled_vesting.setSchedule(accounts[1], non_sequential_schedule, {'from': accounts[0]})


def test_rescue_erc20():
    # Deploy the NUT and esNUT contracts
    nut = NUT.deploy({'from': accounts[0]})
    esnut = esNUT.deploy(nut.address, {'from': accounts[0]})
    nut.grantRole(nut.MINTER_ROLE(), esnut, {"from": accounts[0]})

    scheduled_vesting = ScheduledVesting.deploy(esnut.address, {'from': accounts[0]})

    # Mistakenly send esNUT to the ScheduledVesting contract
    esnut.transfer(scheduled_vesting.address, 1e25, {"from": accounts[0]})
    assert esnut.balanceOf(scheduled_vesting.address) == 1e25

    # Use rescueERC20 to recover the esNUT tokens
    scheduled_vesting.rescueERC20(esnut.address, accounts[0], 1e25, {'from': accounts[0]})
    assert esnut.balanceOf(scheduled_vesting.address) == 0
    assert esnut.balanceOf(accounts[0]) == 1e28 # original balance 

    linear_vesting = LinearVesting.deploy(esnut.address, nut.address, {'from': accounts[0]})

    # Mistakenly send esNUT to the LinearVesting contract
    esnut.transfer(linear_vesting.address, 1e25, {"from": accounts[0]})
    assert esnut.balanceOf(linear_vesting.address) == 1e25

    # Use rescueERC20 to recover the esNUT tokens
    linear_vesting.rescueERC20(esnut.address, accounts[0], 1e25, {'from': accounts[0]})
    assert esnut.balanceOf(linear_vesting.address) == 0
    assert esnut.balanceOf(accounts[0]) == 1e28 # original balance 

def test_linear_vesting_additional():
    # Setup common variables
    nut = NUT.deploy({'from': accounts[0]})
    esnut = esNUT.deploy(nut.address, {'from': accounts[0]})
    nut.grantRole(nut.MINTER_ROLE(), esnut, {"from": accounts[0]})
    
    linear_vesting = LinearVesting.deploy(esnut.address, nut.address, {'from': accounts[0]})
    esnut.grantRole(esnut.UNLOCK_ROLE(), linear_vesting, {"from": accounts[0]})
    esnut.grantRole(esnut.TRANSFER_ROLE(), linear_vesting, {"from": accounts[0]})

    # 1. startVesting with insufficient esNUT
    with brownie.reverts("LinearVesting: Insufficient esNUT balance"):
        linear_vesting.startVesting(1e20, {'from': accounts[1]})
    
    # 2. startVesting with Lock condition
    esnut.transfer(accounts[1], 1e20, {"from": accounts[0]})
    esnut.approve(linear_vesting, 1e20, {'from': accounts[1]})
    linear_vesting.lock(1e6, 1e20, {'from': accounts[1]})
    with brownie.reverts("LinearVesting: Insufficient esNUT locked"):
        linear_vesting.startVesting(1e20, {'from': accounts[1]})

    # 2b. Lock again to extend lock
    linear_vesting.lock(1e6, 1e20, {'from': accounts[1]}) 

    # 3. claimVestedToken after the entire vesting duration
    esnut.transfer(accounts[2], 1e20, {"from": accounts[0]})
    esnut.approve(linear_vesting, 1e20, {'from': accounts[2]})
    linear_vesting.startVesting(1e20, {'from': accounts[2]})
    brownie.chain.sleep(90 * 24 * 60 * 60 + 1)  # Sleep for 90 days + 1 second
    linear_vesting.claimVestedTokens({'from': accounts[2]})
    assert nut.balanceOf(accounts[2]) == 1e20, "claim after vesting period failed"

    # 4. lock with insufficient esNUT
    with brownie.reverts("LinearVesting: Insufficient esNUT balance"):
        linear_vesting.lock(1e6, 1e20, {'from': accounts[3]})
    
    # 5. lock after admin sets overrideLockEndTime
    esnut.transfer(accounts[3], 1e20, {"from": accounts[0]})
    esnut.approve(linear_vesting, 1e20, {'from': accounts[3]})
    linear_vesting.overrideLockEndTime(accounts[3], brownie.chain.time() + 1e6, 1e20, {'from': accounts[0]})
    with brownie.reverts("LinearVesting: Account Ineligible for Locking"):
        linear_vesting.lock(1e6, 1e20, {'from': accounts[3]})
    
    # 6. earlyWithdraw after the entire vesting duration
    esnut.transfer(accounts[4], 1e20, {"from": accounts[0]})
    esnut.approve(linear_vesting, 1e20, {'from': accounts[4]})
    linear_vesting.startVesting(1e20, {'from': accounts[4]})
    brownie.chain.sleep(90 * 24 * 60 * 60 + 1)  # Sleep for 90 days + 1 second
    with brownie.reverts("LinearVesting: Vesting complete, no early withdrawal available"):
        linear_vesting.earlyWithdraw({'from': accounts[4]})
    
    # 7. earlyWithdraw after 67.5 days   
    esnut.transfer(accounts[5], 1e20, {"from": accounts[0]})
    esnut.approve(linear_vesting, 1e20, {'from': accounts[5]})
    linear_vesting.startVesting(1e20, {'from': accounts[5]})
    brownie.chain.sleep(70 * 24 * 60 * 60)  # Sleep for 70 days (linear penalty should be less than floor penalty of 25%) 
    linear_vesting.earlyWithdraw({'from': accounts[5]})

    # 8. overrideLockEndTime with a past timestamp
    with brownie.reverts("LinearVesting: Timestamp should be in the future"):
        linear_vesting.overrideLockEndTime(accounts[6], brownie.chain.time() - 1e6, 1e20, {'from': accounts[0]})
    
    # 9. cancelVesting without a schedule
    with brownie.reverts("LinearVesting: No Vesting In Progress"):
        linear_vesting.cancelVesting({'from': accounts[7]})
    
    # 10. cancelVesting with a schedule
    esnut.transfer(accounts[8], 1e20, {"from": accounts[0]})
    esnut.approve(linear_vesting, 1e20, {'from': accounts[8]})
    linear_vesting.startVesting(1e20, {'from': accounts[8]})
    linear_vesting.cancelVesting({'from': accounts[8]})
    assert esnut.balanceOf(accounts[8]) == 1e20, "cancelVesting failed"

