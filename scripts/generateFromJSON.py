import json, sys, os
from brownie import *

owner = accounts.load("owner")

merkleMap = {
  "ARBITRUM_USER_INCENTIVE_DATA_JAN_29_FEB_02.proof.json": "0x9FB3985b1FAD450C2F4742dd29DBA5380ac7dDe1",
  "ARBITRUM_USER_INCENTIVE_DATA_FEB_02_FEB_09.proof.json": "0x8075d95BF16215e356E97eE74A592c675dCc8D65",
}


def generate(FN, TT = False):

  nut = NUT.at("0x9eA2553267c28CC8F68489FEc85d069d5607DCB0")
  REWARD_TOKEN = "0x9eA2553267c28CC8F68489FEc85d069d5607DCB0" if TT else "0x912ce59144191c1204e64559fe8253a0e49e6548"
  
  if FN[-5:] != ".json": 
  	print("JSON ndeeded")
  	return
  
  # Generate CSV
  FN_CSV = FN[0:-5] + ".csv"
  fn_json = json.load(open("scripts/"+FN))
  csved = [(i, fn_json[i]["week_incentive"]) for i in fn_json]
  open("scripts/"+FN_CSV, "w").write("\n".join(["%s,%i"%(i[0], i[1]) for i in csved]))
  
  os.system("cd scripts; python3 generateProof.py %s"%FN_CSV)
  proofTree = json.load(open("scripts/"+FN_CSV + ".proofTree.json", "r"))
  proofs = json.load(open("scripts/"+FN_CSV + ".proof.json", "r"))
  
  m = MerkleDistributor.deploy(REWARD_TOKEN, proofTree[-1][0], {"from": a[0]})
  
  if TT: nut.mint(m, sum(i[1] for i in csved), {"from": owner})
  print("%i tokens total."%(sum(i[1] for i in csved)))
  
  for i in range(len(csved)):
      addr, amt = list(csved[i])
      assert fn_json[addr]["week_incentive"] == amt
      fn_json[addr]["proof"] = proofs[i]
      fn_json[addr]["index"] = i
      fn_json[addr]["week_incentive"] = str(fn_json[addr]["week_incentive"]) # JSON parsing on browser causes rounding
  
  if TT:
    for addr in list(fn_json.keys())[0:10]:
         m.claim.call(fn_json[addr]["index"], addr, fn_json[addr]["week_incentive"], fn_json[addr]["proof"], {"from": a[0]})
         print("Sent %i TOKEN to %s"%(int(fn_json[addr]["week_incentive"])/1e18, addr))
  
  json.dump(fn_json, open("scripts/"+FN[0:-5] + ".proof.json", "w"))
  return m

def test(FN, m):
  fn_json = json.load(open("scripts/" + FN[0:-5] + ".proof.json"))
  for addr in list(fn_json.keys())[0:10]:
       m.claim.call(fn_json[addr]["index"], addr, fn_json[addr]["week_incentive"], fn_json[addr]["proof"], {"from": a[0]})
       print("Sent %i TOKEN to %s"%(int(fn_json[addr]["week_incentive"])/1e18, addr))

def findProof(addr):
  proofs = [i for i in os.listdir("scripts/") if i[-11:] == ".proof.json"]
  for fn in proofs:
    fn_json = json.load(open("scripts/" + fn))
    try:
      if addr in fn_json:
        print(fn_json[addr])
        print
    except:
      print("Not found in %s"%fn)



def main():
  print("Use in interactive console. To generate, put the file in the scripts/ folder and run m = generate(fn).")
  print("If test token needed, call generate(fn, True)") 
  print("For testing after token deposited, run test(fn, m)")