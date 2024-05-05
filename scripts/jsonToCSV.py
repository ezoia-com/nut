#!/usr/bin/python3 

import os, sys, json
fn = sys.argv[1]

print("\n".join(["%s,%i"%(i[0],i[1]) for i in json.load(open(fn))]))
