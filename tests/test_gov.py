import pytest, brownie, web3
from web3 import Web3


# timelock roles
TIMELOCK_ADMIN_ROLE  = Web3.keccak(text='TIMELOCK_ADMIN_ROLE ')
PROPOSER_ROLE = Web3.keccak(text='PROPOSER_ROLE')
CANCELLER_ROLE = Web3.keccak(text='CANCELLER_ROLE')
EXECUTOR_ROLE = Web3.keccak(text='EXECUTOR_ROLE')
TIMELOCK_ADMIN_ROLE = Web3.keccak(text='TIMELOCK_ADMIN_ROLE')


@pytest.fixture(scope="module", autouse=True)
def user(a):
  yield a[1]

@pytest.fixture(scope="module", autouse=True)
def admin(a):
  yield a[0]

@pytest.fixture(scope="module", autouse=True)
def nut(NUT, admin):  
  nut = NUT.deploy({"from": admin})
  yield nut

@pytest.fixture(scope="module", autouse=True)
def esnut(esNUT, nut, admin):
  esnut = esNUT.deploy(nut, {"from": admin})
  nut.grantRole(nut.MINTER_ROLE(), esnut, {"from": admin})
  assert nut.hasRole(nut.MINTER_ROLE(), esnut)
  yield esnut

@pytest.fixture(scope="module", autouse=True)
def timelock(TimelockController, esnut, admin):
  # constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin) {
  timelock = TimelockController.deploy(86400*7, [], [], admin, {"from": admin})
  esnut.grantRole(esnut.DEFAULT_ADMIN_ROLE(), timelock, {"from": admin})
  yield timelock  
  
# set up governor with timelock and give all timelock rights to it
@pytest.fixture(scope="module", autouse=True)
def governor(NutGovernor, admin, esnut, timelock):
  governor = NutGovernor.deploy(esnut, timelock, 1, 10, 1e18, {"from": admin})
  timelock.grantRole(PROPOSER_ROLE, governor, {"from": admin})
  timelock.grantRole(CANCELLER_ROLE, governor, {"from": admin})
  timelock.grantRole(EXECUTOR_ROLE, governor, {"from": admin})
  timelock.grantRole(TIMELOCK_ADMIN_ROLE, governor, {"from": admin})
  yield governor

@pytest.fixture(autouse=True)
def isolation(fn_isolation):
  pass


def test_revoke_timelock_admin_rights(user, admin, timelock, governor, esnut):
  assert timelock.hasRole(TIMELOCK_ADMIN_ROLE , admin)
  timelock.revokeRole(TIMELOCK_ADMIN_ROLE , admin, {"from": admin})
  assert not timelock.hasRole(TIMELOCK_ADMIN_ROLE , admin)
  
  
def test_proposal_mint_tokens(user, admin, timelock, governor, esnut, NutGovernor, chain):
  assert esnut.balanceOf(user) == 0
  desc = "Mint 1e18 for user"
  with brownie.reverts("Governor: proposer votes below proposal threshold"):
    governor.propose([esnut.address], [0], [esnut.mint.encode_input(user, 1e18)], desc, {"from": admin})
  esnut.mint(admin, 1e18, {"from": admin})
  esnut.delegate(admin, {"from": admin})
  
  proposalId = governor.hashProposal([esnut.address], [0], [esnut.mint.encode_input(user, 1e18)], Web3.keccak(text=desc))

  governor.propose([esnut.address], [0], [esnut.mint.encode_input(user, 1e18)], desc, {"from": admin})
  with brownie.reverts("Governor: unknown proposal id"):
    governor.castVote(proposalId+1, 1, {"from": admin})
  
  with brownie.reverts("Governor: proposal not successful"):
    governor.execute([esnut.address], [0], [esnut.mint.encode_input(user, 1e18)], Web3.keccak(text=desc), {"from": admin})
  
  chain.mine(1)
  governor.castVote(proposalId, 1, {"from": admin}) # 0 = against, 1 = for, 2 = abstain
  chain.mine(governor.votingPeriod() + 1)
  with brownie.reverts("TimelockController: operation is not ready"):
    governor.execute([esnut.address], [0], [esnut.mint.encode_input(user, 1e18)], Web3.keccak(text=desc), {"from": admin})
  chain.mine(governor.votingDelay())
  
  with brownie.reverts('TimelockController: operation is not ready'):
    governor.execute([esnut.address], [0], [esnut.mint.encode_input(user, 1e18)], Web3.keccak(text=desc), {"from": admin})
  
  governor.queue([esnut.address], [0], [esnut.mint.encode_input(user, 1e18)], Web3.keccak(text=desc), {"from": admin})

  with brownie.reverts('TimelockController: operation is not ready'):
    governor.execute([esnut.address], [0], [esnut.mint.encode_input(user, 1e18)], Web3.keccak(text=desc), {"from": admin})
  
  chain.sleep(timelock.getMinDelay()); chain.mine(1)
  governor.execute([esnut.address], [0], [esnut.mint.encode_input(user, 1e18)], Web3.keccak(text=desc), {"from": user})
  
  assert esnut.balanceOf(user) == 1e18
