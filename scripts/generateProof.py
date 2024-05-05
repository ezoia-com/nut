#!/usr/bin/python3

import web3, json, sys, copy
from eth_abi.packed import encode_single_packed, encode_abi_packed

FN = sys.argv[1]

l = open(FN).read().split("\n")
while l[-1] == "": l.pop() # Get rid of empty lines at the end, if any

hashList = []
for i in range(len(l)):
  addr, amt = l[i].split(",", 2)
  hashList.append( web3.Web3.keccak( encode_abi_packed(['uint256','address','uint256'], (i, addr, int(amt))) ) )

hashTree = [hashList]

placeHolder = web3.Web3.keccak( encode_abi_packed(['uint256','address','uint256'], (2**256-1, "0x0000000000000000000000000000000000000000", 0)) )

while len(hashTree[-1]) != 1:
  thisRound = hashTree[-1]
  nextRound = []
  if len(thisRound) % 2 == 1: thisRound.append( placeHolder )
  for i in range(0, len(thisRound), 2):
    if thisRound[i] > thisRound[i+1]: nextRound.append( web3.Web3.keccak(encode_abi_packed(["bytes32","bytes32"], (thisRound[i+1], thisRound[i]))) )
    else:                             nextRound.append( web3.Web3.keccak(encode_abi_packed(["bytes32","bytes32"], (thisRound[i], thisRound[i+1]))) )
  print("Next level done, elements: %i"%len(nextRound))
  hashTree.append(nextRound)
  if len(nextRound) == 0: raise Exception("!")

hexTree = [[j.hex() for j in i] for i in hashTree]
json.dump( hexTree, open(FN + ".proofTree.json","w"))

proofs = []

for i in range(len(l)):
  addr, amt = l[i].split(",", 2)
  #print(i, addr, amt)
  #print("Leaf: ", hexTree[0][i])
  tmp_i = i
  proof = []
  for j in range(0, len(hexTree) - 1):
    if tmp_i % 2 == 0: proof.append(hexTree[j][ tmp_i + 1])
    else:              proof.append(hexTree[j][ tmp_i - 1])
    tmp_i = int(tmp_i / 2)
  proofs.append(proof)
  #print(proof)

json.dump( proofs, open(FN + ".proof.json","w"))
