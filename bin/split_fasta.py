#!/usr/bin/env python

"""
usage: ./split_fasta.py test.fasta(.gz) 50
"""

import sys
import random
from Bio import SeqIO

def check(args):
    import os.path
    if os.path.isfile(args[0]):
        fasta = args[0]
    else:
        print __doc__
	print "File not found\n"
        sys.exit(1)

    try:
	n = int(args[1])
    except:
	print __doc__
	print "Specify number of batches as integer\n"
	sys.exit(2)
    return fasta,n

def open_fasta(f):
    if f[-2:] == "gz":
        import gzip
	fh = gzip.open(f)
    else:
	fh = open(f)
    return fh
    
def setup_dic(n):
    dic = {}
    for i in range(1,n+1):
    	dic[i] = ""
    return dic

def reset(n):
    l = []
    for i in range(1,n+1):
        l.append(i)
    random.shuffle(l)
    return l

def distribute(fh, n, dic):
    counter = 0
    for r in SeqIO.parse(fh, "fasta"):
        if counter%n == 0:
                l = reset(n)
#		print l
        target = l.pop()
#	print r.id,target
        dic[target] += ">%s\n%s\n" %(r.id, str(r.seq))
        counter+=1

def cleanup(dic):
    """ 
    rename the keys in the dictionary with leading zeros, in the process removing empty elements (happens when actual number of contigs is smaller than n)
    """
    counter = 1
    keys = dic.keys()
    for b in keys:
        if dic[b]:
            dic["%04d"%counter] = dic.pop(b)
            counter+=1
        else:
            del(dic[b])
        
def write(dic):
    for b in dic.keys():
        fh = open(b+".fasta", "w")
        fh.write(dic[b])
        fh.close()


if __name__ == '__main__':

    fasta , n = check(sys.argv[1:])
    d = setup_dic(n)
    distribute(open_fasta(fasta), n, d)
#    print d.keys()
    cleanup(d)
#    print d.keys()
    write(d)

#cat <(echo -e "50") ../Eubothrium/assembly/PLATANUS/Ecr_Fus_St-wr/Ecr_Fus_St-wr_scaffold.fa | perl -ne 'chomp; if ($. == 1){$n = $_}else{if ($_=~ />/){if ($s){open(FH, ">>", sprintf("%04d", int(rand($n)+1)).".fasta"); print FH "$h\n$s\n"; close(FH)}; $h=$_}else{$s.=$_}}'
