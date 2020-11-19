#!/usr/bin/env python
from __future__ import print_function
import sys
import argparse



pars = argparse.ArgumentParser(prog="makergff2funannotategff.py", description = """Converts a MAKER GFF file to file compatible with funannotate""", epilog = """written by Philipp Resl 2020""")
pars.add_argument('-gff', dest="gff", required=True, help="Input GFF file from MAKER")
args=pars.parse_args()

gff_file = open(args.gff, "r")

print("##gff-version 3")
for line in gff_file:
	if "\tcontig\t" in line:
		continue
	if "\tmaker\t" in line:
		if ":exon:" in line:
			line = line.replace(":exon:", ".exon")
		if ":cds" in line:
			line = line.replace(":cds", ".cds")
		if ":five_prime_utr":
			line = line.replace(":five_prime_utr", ".five_prime_utr")
		if ":three_prime_utr":
			line = line.replace(":three_prime_utr", ".three_prime_utr")
		print(line.strip())
		if "##FASTA" in line:
			break
