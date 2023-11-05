# Run this with "brownie test <thisFile> -s" and change FN variable to point at list.txt. 
# "-s" allows standard output to reach user, for visual comfort. 


import json, brownie, pytest

def test_basic_deposit_and_withdrawal(a, NUT, MerkleDistributor):
  FN = "scripts/list.txt"
  nuts = NUT.deploy({"from": a[0]})
  nuts.mint(a[0], 100e18, {"from": a[0]})
  proofTree = json.load(open(FN + ".proofTree.json", "r"))
  m = MerkleDistributor.deploy(nuts, proofTree[-1][0], {"from": a[0]})
  nuts.transfer(m, 100e18, {"from": a[0]})
  proofs = json.load(open(FN + ".proof.json", "r"))
  l = open(FN, "r").read().split("\n")
  for i in range(len(proofs)):
    addr, amt = l[i].split(",",2)
    m.claim(i, addr, int(amt), proofs[i], {"from": a[0]})
  for i in range(len(proofs)):
    addr, amt = l[i].split(",",2)
    with brownie.reverts("MerkleDistributor: Drop already claimed."): tx = m.claim(i, addr, int(amt), proofs[i], {"from": a[0]})
    if nuts.balanceOf(addr) != int(amt): raise Exception("nuts mismatch")
    else: print("Account %i has received correct number of tokens"%(i))
