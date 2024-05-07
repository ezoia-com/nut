import brownie
import pytest
from brownie import NUT, esNUT, accounts, ScheduledVesting, LinearVesting, chain, history
from decimal import Decimal

@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

# Multiple vestings coverage
def test_vesting_fix():
    # Deploy esNUT contracts
    esnut = esNUT.deploy({'from': accounts[0]})
    esnut.mint(accounts[0], 1e28, {"from": accounts[0]})
    nut = NUT.at(esnut.nutToken());

    linearVesting = LinearVesting.deploy(esnut, {"from": accounts[0]})
    
    esnut.grantRole(esnut.UNLOCK_ROLE(), linearVesting, {"from": accounts[0]})
    esnut.grantRole(esnut.TRANSFER_ROLE(), linearVesting, {"from": accounts[0]})
    
    linearVesting.setFeeCollector(accounts[4], {"from": accounts[0]})

    # Test case: User calls startVesting multiple times, then calls earlyWithdraw
    esnut.transfer(accounts[3], 2e26, {"from": accounts[0]})  # Transfer 2e26 esNUT to accounts[3]
    esnut.approve(linearVesting, 2e26, {'from': accounts[3]})

    # First vesting
    linearVesting.startVesting(1e26, {'from': accounts[3]})

    # Second vesting after 30 days
    chain.mine(timestamp=linearVesting.vestingSchedules(accounts[3])[0] + 60 * 60 * 24 * 30)
    linearVesting.startVesting(1e26, {'from': accounts[3]})

    # earlyWithdraw after 15 days
    chain.mine(timestamp=linearVesting.vestingSchedules(accounts[3])[0] + 60 * 60 * 24 * 15)
    linearVesting.earlyWithdraw({'from': accounts[3]})
    
    # Check balances
    assert esnut.balanceOf(linearVesting) == 0
    assert esnut.balanceOf(accounts[3]) == 0

    # Calculate the expected NUT balance after the 2 vesting actions and earlyWithdraw
    # First vesting: 30 days
    elapsed_time_1 = Decimal(30 * 24 * 60 * 60)  # 30 days in seconds
    vested_amount_1 = (elapsed_time_1 * int(Decimal(str(1e26)))) // Decimal(90 * 24 * 60 * 60)  # 1e26 esNUT vested over 90 days
    unvested_amount_1 = int(Decimal(str(1e26))) - vested_amount_1
    
    # Second vesting: 45 days (15 days after first vesting)
    elapsed_time_2 = Decimal(15 * 24 * 60 * 60)  # 15 days in seconds
    vested_amount_2 = (elapsed_time_2 * (int(Decimal(str(1e26))) + unvested_amount_1)) // Decimal(90 * 24 * 60 * 60)  # 1e26 esNUT + unvested from first vesting, vested over 90 days
    
    # Total vested amount
    total_vested_amount = vested_amount_1 + vested_amount_2
    
    # Unvested amount at the time of earlyWithdraw
    unvested_amount = int(Decimal(str(2e26))) - total_vested_amount
    
    # Penalty percentage at 15 days since second vesting started
    penalty_percentage = int(Decimal(str(1e18)) - (Decimal(15 * 24 * 60 * 60) * int(Decimal(str(1e18)))) // Decimal(90 * 24 * 60 * 60))
    if penalty_percentage < linearVesting.minPenalty():
        penalty_percentage = linearVesting.minPenalty()
    
    penalty_amount = (penalty_percentage * unvested_amount) // int(Decimal(str(1e18)))
    expected_nut_balance = total_vested_amount + (unvested_amount - penalty_amount)
    
    assert nut.balanceOf(accounts[3]) == expected_nut_balance

    # Early withdraw penalty should be in the fee collector
    assert esnut.balanceOf(linearVesting.feeCollector()) == penalty_amount


def test_two_full_vestings_90_days_apart():

    # Deploy esNUT contracts
    esnut = esNUT.deploy({'from': accounts[0]})
    esnut.mint(accounts[0], 1e28, {"from": accounts[0]})
    nut = NUT.at(esnut.nutToken());

    linearVesting = LinearVesting.deploy(esnut, {"from": accounts[0]})
    
    esnut.grantRole(esnut.UNLOCK_ROLE(), linearVesting, {"from": accounts[0]})
    esnut.grantRole(esnut.TRANSFER_ROLE(), linearVesting, {"from": accounts[0]})
    
    linearVesting.setFeeCollector(accounts[4], {"from": accounts[0]})

    # Test case: User calls startVesting twice, 90 days apart
    esnut.transfer(accounts[3], 2e26, {"from": accounts[0]})  # Transfer 2e26 esNUT to accounts[3]
    esnut.approve(linearVesting, 2e26, {'from': accounts[3]})

    # First vesting
    linearVesting.startVesting(1e26, {'from': accounts[3]})

    # Advance time by 90 days
    chain.mine(timestamp=linearVesting.vestingSchedules(accounts[3])[0] + 60 * 60 * 24 * 90)

    # Claim vested tokens from first vesting
    linearVesting.claimVestedTokens({'from': accounts[3]})

    # Second vesting
    linearVesting.startVesting(1e26, {'from': accounts[3]})

    # Advance time by another 90 days
    chain.mine(timestamp=linearVesting.vestingSchedules(accounts[3])[0] + 60 * 60 * 24 * 90)

    # Claim vested tokens from second vesting
    linearVesting.claimVestedTokens({'from': accounts[3]})
    
    # Check balances
    assert esnut.balanceOf(linearVesting) == 0
    assert esnut.balanceOf(accounts[3]) == 0
    assert nut.balanceOf(accounts[3]) == 2e26  # All esNUT should be converted to NUT without penalty