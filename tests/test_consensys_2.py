import brownie
import pytest
from brownie import NUT, esNUT, accounts, ScheduledVesting, LinearVesting, chain, history
from decimal import Decimal

@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

# 5.2 Incorrect Custom Vesting Schedule May Block Vesting
def test_consensys_2():
    # Deploy the NUT and esNUT contracts
    esnut = esNUT.deploy({'from': accounts[0]})
    esnut.mint(accounts[0], 1e28, {"from": accounts[0]})
    nut = NUT.at(esnut.nutToken());
    
    # Deploy vesting contracts
    linear_vesting = LinearVesting.deploy(esnut.address, {'from': accounts[0]})
    scheduled_vesting = ScheduledVesting.deploy(esnut.address, linear_vesting, {'from': accounts[0]})
    
    # Grant UNLOCK role to scheduled_vesting
    esnut.grantRole(esnut.UNLOCK_ROLE(), scheduled_vesting, {"from": accounts[0]})
    
    # Cover case where schedule is missing
    with brownie.reverts("ScheduledVesting: Schedule length must be greater than 0"):
        scheduled_vesting.setSchedule(accounts[1], [])
    
    # Define schedule    
    schedule = [
        (brownie.chain.time() + 60 * 60 * 24, int(Decimal("1e25"))),
        (brownie.chain.time() + 60 * 60 * 48, int(Decimal("1e25")))
    ]
    
    
    # Check case where ADMIN forgets to call overrideLockEndTime
    with brownie.reverts("ScheduledVesting: Lock schedule not set"):
        scheduled_vesting.setSchedule(accounts[1], schedule)
    
    # Call LinearVesting to lock esNUT for duration of schedule with incorrect lock count
    linear_vesting.overrideLockEndTime(accounts[1], schedule[-1][0], sum(i[1] for i in schedule) + 1) 


    # Check case where ADMIN sets expiry but doesn't set schedule again until much later
    chain.snapshot()
    chain.mine( timestamp = schedule[-1][0] + 1)
    with brownie.reverts("ScheduledVesting: Lock schedule already expired"):
        scheduled_vesting.setSchedule(accounts[1], schedule)
    chain.revert()

    # Check case where ADMIN configures Lock in LinearVesting incorrectly 
    with brownie.reverts("ScheduledVesting: lockSchedule esNUT mismatch proposed schedule"):
        scheduled_vesting.setSchedule(accounts[1], schedule)

    # Call LinearVesting to lock esNUT for duration of schedule with incorrect lock count
    linear_vesting.overrideLockEndTime(accounts[1], schedule[-1][0], sum(i[1] for i in schedule) )
    
    # Check case where ADMIN forgets to fund account
    with brownie.reverts("ScheduledVesting: Insufficient esNUT to lock"):
        scheduled_vesting.setSchedule(accounts[1], schedule)
    
    # Fund scheduled_vesting users
    esnut.transfer(accounts[1], sum( i[1] for i in schedule ), {"from": accounts[0]})

    # Set a vesting schedule for accounts[1] 
    scheduled_vesting.setSchedule(accounts[1], schedule)
    
    # Verify the vesting schedule is stored correctly
    for i, (timestamp, amount) in enumerate(schedule):
        stored_timestamp, stored_amount = scheduled_vesting.schedules(accounts[1], i)
        assert stored_timestamp == timestamp
        assert stored_amount == amount