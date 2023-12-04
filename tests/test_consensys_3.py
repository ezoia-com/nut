import brownie
import pytest
from brownie import NUT, esNUT, accounts, ScheduledVesting, LinearVesting, chain, history
from decimal import Decimal

@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass

# 5.3 The Total Amount of Nut and esNut Tokens Can Exceed the Capped Amount Critical
def test_consensys_3():
    # Deploy esNUT contracts
    esnut = esNUT.deploy({'from': accounts[0]})
    esnut.mint(accounts[0], 1e28, {"from": accounts[0]})
    nut = NUT.at(esnut.nutToken());

    # Check ADMIN_ROLE
    assert nut.hasRole(nut.ADMIN_ROLE(), accounts[0]) == True
    
    # Check mintability by deployer
    with brownie.reverts("ERC20PresetMinterPauser: must have minter role to mint"):
      nut.mint(accounts[0], 1e18, {"from": accounts[0]})
    
    # Check if deployer can assign MINTER_ROLE to itself
    
    # Try to assign DEFAULT_ADMIN_ROLE to itself
    with brownie.reverts():
      nut.grantRole(nut.DEFAULT_ADMIN_ROLE(), accounts[0], {"from": accounts[0]})
    
    # Try to grant MINTER to itself
    with brownie.reverts():
      nut.grantRole(nut.MINTER_ROLE(), accounts[0], {"from": accounts[0]})
    
    # Grant RESCUE_ROLE to itself
    with brownie.reverts():
      nut.rescueERC20(nut, accounts[0], 0, {"from": accounts[0]})
      
    nut.grantRole(nut.RESCUE_ROLE(), accounts[0], {"from": accounts[0]})
    nut.rescueERC20(nut, accounts[0], 0, {"from": accounts[0]})
    nut.revokeRole(nut.RESCUE_ROLE(), accounts[0], {"from": accounts[0]})

    # Grant PAUSE_ROLE to itself
    with brownie.reverts("ERC20PresetMinterPauser: must have pauser role to pause"):
      nut.pause({"from": accounts[0]})
    
    nut.grantRole(nut.PAUSER_ROLE(), accounts[0], {"from": accounts[0]})
    nut.pause({"from": accounts[0]})
    nut.revokeRole(nut.PAUSER_ROLE(), accounts[0], {"from": accounts[0]})
    
    with brownie.reverts("ERC20PresetMinterPauser: must have pauser role to unpause"):
      nut.unpause({"from": accounts[0]})
      
    nut.grantRole(nut.PAUSER_ROLE(), accounts[0], {"from": accounts[0]})
    nut.unpause({"from": accounts[0]})
    nut.revokeRole(nut.PAUSER_ROLE(), accounts[0], {"from": accounts[0]})