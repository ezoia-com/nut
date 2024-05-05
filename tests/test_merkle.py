# Run this with "brownie test <thisFile> -s" and change FN variable to point at list.txt. 
# "-s" allows standard output to reach user, for visual comfort. 


import json, brownie, pytest

def test_basic_deposit_and_withdrawal(a, NUT, MerkleDistributor):
  FN = "scripts/list.txt"
  nuts = NUT.deploy({"from": a[0]})
  nuts.mint(a[0], 41919e18, {"from": a[0]})
  proofTree = json.load(open(FN + ".proofTree.json", "r"))
  m = MerkleDistributor.deploy(nuts, proofTree[-1][0], {"from": a[0]})
  nuts.transfer(m, 100e18, {"from": a[0]})
  proofs = json.load(open(FN + ".proof.json", "r"))
  l = open(FN, "r").read().split("\n")
  for i in range(len(proofs)):
    addr, amt = l[i].split(",",2)
    m.claim.call(i, addr, int(amt), proofs[i], {"from": a[0]})
    print("m.claim(%i, '%s', %s, %s)"%(i, addr, amt, proofs[i]))
  for i in range(len(proofs)):
    addr, amt = l[i].split(",",2)
    with brownie.reverts("MerkleDistributor: Drop already claimed."): tx = m.claim(i, addr, int(amt), proofs[i], {"from": a[0]})
    if nuts.balanceOf(addr) != int(amt): raise Exception("nuts mismatch")
    else: print("Account %i has received correct number of tokens"%(i))

"""
import json
FN = "scripts/ARBITRUM_INCENTIVE_JAN_29_FEB_02.csv"
proofTree = json.load(open(FN + ".proofTree.json", "r"))
proofs = json.load(open(FN + ".proof.json", "r"))
l = open(FN, "r").read().split("\n")
m = MerkleDistributor.at("0xf286229743815b1288e74a0233d3d30bdb1Dfa92")
arb = ERC20.at("0x912ce59144191c1204e64559fe8253a0e49e6548")
arb.transfer(m, 25000e18, {"from": "0xc3A48B40b3762924D6fa3af1D957cE78E522497E"})

for i in range(100):
     addr, amt = l[i].split(",",2)
     m.claim(i, addr, int(amt), proofs[i], {"from": a[0]})
     print("Sent %i ARB to %s"%(int(amt)/1e18, addr))
"""