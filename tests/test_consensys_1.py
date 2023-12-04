import brownie
import pytest
import math
from brownie import NUT, esNUT, accounts, ScheduledVesting, LinearVesting, chain, history

@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

# 5.1 LinearVesting - Incorrect Logic to Return Funds While Vesting Cancellation, Allows Draining of Contract Funds 
def test_consensys_1():
    # Deploy the NUT and esNUT contracts
    nut = NUT.deploy({'from': accounts[0]})
    esnut = esNUT.deploy(nut.address, {'from': accounts[0]})
    esnut.mint(accounts[0], 1e28, {"from": accounts[0]})
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
    claimable = initial_esnut / 2
    vs = linear_vesting.vestingSchedules(accounts[1])
    chain.mine(timestamp = vs[0] + 86400 * 45)
    linear_vesting.claimVestedTokens({'from': accounts[1]})
    assert nut.balanceOf(accounts[1]) >= claimable
    assert esnut.balanceOf(linear_vesting) + nut.balanceOf(accounts[1]) == initial_esnut 
    
    # Cancel after 45 days, make sure balances are expected
    
    vs = linear_vesting.vestingSchedules(accounts[1])
    expectedAmt = vs[1] - vs[2] + esnut.balanceOf(accounts[1])
    chain.mine(timestamp = chain[-1].timestamp ) # Reset timer
    linear_vesting.cancelVesting({"from": accounts[1]})
    assert esnut.balanceOf( accounts[1] ) == expectedAmt
    assert esnut.balanceOf(linear_vesting) == 0
    assert esnut.balanceOf( accounts[1] ) + nut.balanceOf( accounts[1] ) == initial_esnut
