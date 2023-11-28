import brownie
import pytest
import math
from brownie import NUT, esNUT, accounts, ScheduledVesting, LinearVesting, chain, history

@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

"""
Question:
Hi team, the NUT token's mint function is not checked by checkInvariantAfter, 
which means the admin can mint certain amount of NUT token after some NUT token are 
locked into esNut or the Admin has minted some esNUT already, the total amount of 
NUT and esNUT would be more than the total cap, is it a problem?
"""

def test_mint_not_checked_in_NUT():
    # Initial deployment of the NUT contract
    nut = NUT.deploy({'from': accounts[0]})
    assert nut.totalSupply() == 0, "Initial NUT supply is not 0"
    assert nut.cap() == 1e28, "NUT cap is not 1e28"
    assert nut.paused() == False, "NUT contract is paused upon deployment"
    assert nut.hasRole(nut.DEFAULT_ADMIN_ROLE(), accounts[0]), "Deployer doesn't have DEFAULT_ADMIN_ROLE in NUT"
    
    # Can NUT mint more than CAP?
    
    # 1. Let deployer grant minter role to itself
    nut.grantRole(nut.MINTER_ROLE(), accounts[0])
    assert nut.hasRole(nut.MINTER_ROLE(), accounts[0]), "Deployer doesn't have MINTER_ROLE()"
    
    # 2. Mint more than cap
    with brownie.reverts("ERC20Capped: cap exceeded"): 
      nut.mint(accounts[0], nut.cap() + 1e18)
    