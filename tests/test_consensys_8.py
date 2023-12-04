import brownie
import pytest
from brownie import NUT, esNUT, accounts, ScheduledVesting, LinearVesting, chain, history
from decimal import Decimal

@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

# 5.8 esNut - Missing Events for Critical State Changes 
def test_consensys_8():
    # Deploy esNUT contracts
    esnut = esNUT.deploy({'from': accounts[0]})
    esnut.mint(accounts[1], 1e18, {"from": accounts[0]})
    
    # Check initial event firing for TokenLock state
    assert esnut.tx.events["TokenLock"]["locked"] == True
    with brownie.reverts("esNUT: Neither sender nor recipient has TRANSFER_ROLE"):
      esnut.transfer(accounts[1], 0, {"from": accounts[1]})

    tx = esnut.setTokenLock(False, {"from": accounts[0]})
    assert tx.events["TokenLock"]["locked"] == False
    esnut.transfer(accounts[1], 0, {"from": accounts[1]})
