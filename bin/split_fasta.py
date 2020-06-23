#!/usr/bin/env python

"""
usage: ./split_fasta.py test.fasta(.gz) 50
"""

import sys
import random
import os.path

counter = 0
def setup_dic(n):
    dic = {}
    for i in range(1,n+1):
    	dic[i] = ""
    return dic

def reset(n):
    import random
    l = []
    for i in range(1,n+1):
        l.append(i)
    random.shuffle(l)
    return l

def distribute(fh, n, dic):
    from Bio import SeqIO
    counter = 0
    for r in SeqIO.parse(fh, "fasta"):
        if counter%n == 0:
                l = reset(n)
#		print l
        target = l.pop()
#	print r.id,target
        dic[target] += ">%s\n%s\n" %(r.id, str(r.seq))
        counter+=1

def write(dic):
    for b in dic.keys():
        fh = open("%04d"%b+".fasta", "w")
        fh.write(dic[b])
        fh.close()


if __name__ == '__main__':
    if os.path.isfile(sys.argv[1]):
        fasta = sys.argv[1]
    else:
        print __doc__
	print "File not found\n"
        sys.exit(1)

    try:
	n = int(sys.argv[2])
    except:
	print __doc__
	print "Specify number of batches as integer\n"
	sys.exit(2)

    if fasta[-2:] == "gz":
        import gzip
	fh = gzip.open(fasta)
    else:
	fh = open(fasta)

    d=setup_dic(n)
    distribute(fh, n, d)
    write(d)

#cat <(echo -e "50") ../Eubothrium/assembly/PLATANUS/Ecr_Fus_St-wr/Ecr_Fus_St-wr_scaffold.fa | perl -ne 'chomp; if ($. == 1){$n = $_}else{if ($_=~ />/){if ($s){open(FH, ">>", sprintf("%04d", int(rand($n)+1)).".fasta"); print FH "$h\n$s\n"; close(FH)}; $h=$_}else{$s.=$_}}'
