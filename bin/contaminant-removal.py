#!/usr/bin/env python3
import argparse, sys
from collections import OrderedDict

from Bio import SeqIO


def read_contamination_positions(contfilename, exclude=False, trim=False, review=False, fix=False):
	contaminations ={"EXCLUDE": {}, "TRIM": {}, "REVIEW": {}, "FIX": {} }
	with open(contfilename, "r") as contfile:
		for line in contfile:
			if line.startswith("#"):
				continue
			seqid, start, stop, length, what = line.strip().split("\t")[0:5]                
			#print(seqid, start, stop, length, what)
			if what == "EXCLUDE" and exclude:
				if seqid not in contaminations["EXCLUDE"].keys():
					contaminations["EXCLUDE"][seqid] = seqid
			if what == "TRIM" and trim:
				if seqid not in contaminations["TRIM"].keys():
					contaminations["TRIM"][seqid] = [(start, stop)]
				else:
					contaminations["TRIM"][seqid].append((start, stop))
			if what == "FIX" and fix:
				if seqid not in contaminations["FIX"].keys():
					contaminations["FIX"][seqid] = [(start, stop)]
				else:
					contaminations["FIX"][seqid].append((start, stop))
			if what == "REVIEW" and review:
				if seqid not in contaminations["REVIEW"].keys():
					contaminations["REVIEW"][seqid] = seqid
	return contaminations

def remove_contaminations(assemblyfile, contaminations):
	seqid = ""
	# read in assembly:
	records = SeqIO.parse(assemblyfile, "fasta")
	assembly = OrderedDict()
	for record in records:
		assembly[record.id] = str(record.seq)
	
	#remove sequences marked with EXCLUDE:
	for contig in contaminations["EXCLUDE"]:
		print("EXCLUDE:", contig, file=sys.stderr)
		del assembly[contig]
	
	#remove sequences marked with REVIEW:
	for contig in contaminations["REVIEW"]:
		print("EXCLUDE (from REVIEW):", contig, file=sys.stderr)
		del assembly[contig]

	#trim positions marked with TRIM:
	for contig in contaminations["TRIM"].keys():
		sequence = assembly[contig]
		for position in contaminations["TRIM"][contig]:
			print("Will TRIM:", position, "in", contig, file=sys.stderr)
			start = int(position[0]) - 1
			stop = int(position[1])
			length = stop - start + 1
			new_sequence = ""
			for i in range(0, len(sequence)-1):
				if i >= start and i < stop:
					new_sequence += "Q"
				else:
					new_sequence += sequence[i]			
			sequence = new_sequence
		assembly[contig] = sequence.replace("Q", "")
	
	#fix positions marked with FIX
	for contig in contaminations["FIX"].keys():
		sequence = assembly[contig]
		for position in contaminations["FIX"][contig]:
			print("Will FIX:", position, "in", contig, file=sys.stderr)
			start = int(position[0]) - 1
			stop = int(position[1])
			length = stop - start + 1
			new_sequence = ""
			for i in range(0, len(sequence)-1):
				if i >= start and i < stop:
					new_sequence += "N"
				else:
					new_sequence += sequence[i]			
			sequence = new_sequence
		assembly[contig] = sequence
	return assembly
			
if __name__ == "__main__":
	parser = argparse.ArgumentParser(description="This script masks position in an assembly with Ns. It was written to handle the NCBI contamination screen when genomes are submitted to Genbank.")
	parser.add_argument("-a", dest="assembly", help="Assembly file in FASTA")
	parser.add_argument("-c", dest="cont", help="Contamination table file from FCS-GX")
	parser.add_argument("--exclude", dest="exclude", action="store_true", default=False, help="Remove contaminations marked as EXCLUDE. This removes the whole sequence.")
	parser.add_argument("--trim", dest="trim", action="store_true", default=False, help="Remove contaminations marked TRIM. This reduces the length of the sequence.")
	parser.add_argument("--review", dest="review", action="store_true", default=False, help="Remove contaminations marked with REVIEW. This removes the whole sequence.")
	parser.add_argument("--fix", dest="fix", action="store_true", default=False, help="Remove contaminations marked with FIX. This masks (with Ns) the contaminated part of the sequence.")
	if len(sys.argv)<2:
		parser.print_help()
		sys.exit()
	args = parser.parse_args()

	if not args.cont:
		print("Need a contamination report table file from FCS-GX. Specify with -c.", file=sys.stderr)
		sys.exit(0)
	if not args.assembly:
		print("Need an assembly file in FASTA format. Specify with -a.", file=sys.stderr)
		sys.exit(0)

	contaminations = read_contamination_positions(args.cont, args.exclude, args.trim, args.review, args.fix)	
	new_assembly = remove_contaminations(args.assembly, contaminations)
	for seqid, sequence in new_assembly.items():
		print(">"+seqid)
		print(sequence)
		
