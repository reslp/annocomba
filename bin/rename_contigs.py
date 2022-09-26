#!/usr/bin/env python

import sys

if len(sys.argv) < 3:
	print("Too few arguments")
	exit(0)

assembly_file = sys.argv[1]
prefix = sys.argv[2]

n_contig = 1
for line in open(assembly_file, "r"):
	if line.startswith(">"):
		print(">"+prefix+"_"+str(n_contig))
		n_contig += 1
	else:
		print(line.strip())

