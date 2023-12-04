import brownie
import pytest
from brownie import NUT, esNUT, accounts, ScheduledVesting, LinearVesting, chain, history
from decimal import Decimal

@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

# 5.5 Malicious Admin Can Steal Funds From Contracts 
def test_consensys_5():
    # Deploy esNUT contracts
    esnut = esNUT.deploy({'from': accounts[0]})
    esnut.mint(accounts[0], 1e28, {"from": accounts[0]})
    nut = NUT.at(esnut.nutToken());

    linearVesting = LinearVesting.deploy(esnut, {"from": accounts[0]})
    
    with brownie.reverts("LinearVesting: Cannot rescue esNUT"):
      linearVesting.rescueERC20(esnut.address, accounts[0], 0, {"from": accounts[0]})