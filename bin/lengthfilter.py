#!/usr/bin/env python

"""
usage: ./lengthfilter.py test.fasta(.gz) 1000
"""

import sys
from Bio import SeqIO

def check(args):
    import os.path
    if os.path.isfile(args[0]):
        fasta = args[0]
    else:
        print(__doc__)
        print("File not found\n")
        sys.exit(1)

    try:
        m = int(args[1])
    except:
        print(__doc__)
        print("Specify minimum length as integer\n")
        sys.exit(2)
    try:
        ns = float(args[2])
    except:
        print(__doc__)
        print("Specify N percentage as value between 0 and 1.\n")
        sys.exit(2)
    return fasta, m, ns

def open_fasta(f):
    if f[-2:] == "gz":
        import gzip
        fh = gzip.open(f)
    else:
        fh = open(f)
    return fh
    
def filt(fh, m, ns):
    for r in SeqIO.parse(fh, "fasta"):
        if len(r.seq) >= m and r.seq.lower().count("n")/len(r.seq) < ns:
            print(">" + r.id.replace(" ", "_").replace("|","_") + "\n" + str(r.seq)) # replace several special characters to prevent unintended changes to the sequence ids.


if __name__ == '__main__':

    fasta, m, ns = check(sys.argv[1:])
    filt(open_fasta(fasta), m, ns)

#cat <(echo -e "50") ../Eubothrium/assembly/PLATANUS/Ecr_Fus_St-wr/Ecr_Fus_St-wr_scaffold.fa | perl -ne 'chomp; if ($. == 1){$n = $_}else{if ($_=~ />/){if ($s){open(FH, ">>", sprintf("%04d", int(rand($n)+1)).".fasta"); print FH "$h\n$s\n"; close(FH)}; $h=$_}else{$s.=$_}}'
