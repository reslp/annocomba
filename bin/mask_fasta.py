#!/usr/bin/env python

"""
usage: mask_fasta.py test.fasta(.gz) test.gff mode
"""

import sys
from Bio import SeqIO

def check(args):
    import os.path
    if os.path.isfile(args[0]):
        fasta = args[0]
    else:
        print(__doc__)
        print("fasta not found\n")
        sys.exit(1)
    if os.path.isfile(args[1]):
        gff = args[1]
    else:
        print(__doc__)
        print("gff not found\n")
        sys.exit(2)
    if args[2] == 'soft' or args[2] == 'hard':
        mode = args[2]
    else:
        print(__doc__)
        print("specify masking mode - either soft or hard\n")
        sys.exit(3)
	

    return fasta,gff,mode

def open_file(f):
    if f[-2:] == "gz":
        import gzip
        fh = gzip.open(f)
    else:
        fh = open(f)
    return fh

def parse_gff(fh):
    dic = {}
    for l in fh:
        if not l.startswith("#"):
            li = l.strip().split("\t")
            if not li[0] in dic:
                dic[li[0]] = [[li[3],li[4]]]
            else:
                dic[li[0]].append([li[3],li[4]])
    return dic

def mask(fh, dic, mode):
    for r in SeqIO.parse(fh, "fasta"):
        if r.id in dic:
            for i in range(len(dic[r.id])):
                if mode == 'soft':
                    r.seq = r.seq[0:int(dic[r.id][i][0])-1] + r.seq[int(dic[r.id][i][0])-1:int(dic[r.id][i][1])].lower() + r.seq[int(dic[r.id][i][1]):]
                elif mode == 'hard':
                    r.seq = r.seq[0:int(dic[r.id][i][0])-1] + "N"*int(int(dic[r.id][i][1])-int(dic[r.id][i][0])+1) + r.seq[int(dic[r.id][i][1]):]
        print(">"+r.id+"\n"+r.seq)

if __name__ == '__main__':

    fasta , gff , mode = check(sys.argv[1:])
    mask(open_file(fasta), parse_gff(open_file(gff)), mode)
