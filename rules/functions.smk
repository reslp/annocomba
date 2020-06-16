
import pandas as pd
import os
import glob
from math import ceil
from pathlib import Path
from subprocess import call


n=int(config["split_batch_length"])
min=int(config["split_min_length"])

samples = pd.read_csv(config["samples"], sep="\t").set_index("sample", drop=False)
samples.index.names = ["sample_id"]

dic = {'sample': [], 'unit': []}

def get_assembly_path(wildcards):
# this is to get the path to the assembly from the CSV file
	return samples.loc[wildcards.sample, ["fasta"]].to_list()

def get_transcripts_path(wildcards, p="data/transcripts/*"):
	#get paths to fasta transcript fasta files - if file has prefix identical to sample prefix in data.csv -> assume it's a transcriptome of this species -> MAKER 'est' option
	dic = {'alt_ests': [], 'ests': []}
	for f in glob.glob(p):
		if f.split("/")[-1].startswith(wildcards.sample):
			dic['ests'].append(os.path.abspath(f))
		else:
			dic['alt_ests'].append(os.path.abspath(f))
	return dic


def partition_by_length(fasta, max_length=n, min_length=min, pr=0, outdir="./"):
#function that partitions the fasta file
	headers = []
	seqs = []
	i=0
	cum_length=0
	printcount=1
	for line in open(str(fasta)).readlines():
		if line.strip().startswith(">"):
			headers.append(line.strip())
			seqs.append("")
			if i >= 1:
				if len(seqs[-2]) >= min_length:
					cum_length+=len(seqs[-2])
#					print("%s\t%s\t%s" %(headers[-2], len(seqs[-2]), cum_length))
				else:
					del headers[-2]
					del seqs[-2]
			if cum_length >= max_length:
				if pr:
					if not os.path.exists(outdir+"/"+str(printcount).zfill(4)):
						os.mkdir(outdir+"/"+str(printcount).zfill(4))
					fh = open(outdir+"/"+str(printcount).zfill(4)+"/p0001", 'w')
#					print("%s\t%s" %(str(printcount).zfill(4), cum_length)) #"{:04d}".format(printcount))
					for j in range(len(headers)-1):
						fh.write("%s\n%s\n" %(headers[j],seqs[j]))
					fh.close()
				for j in reversed(range(len(headers)-1)):
					del headers[j]
					del seqs[j]
					cum_length=len(seqs[-1])
#				print("the lenght is again: %s" %len(headers))
				printcount+=1
			i+=1
		else:
			seqs[-1] = seqs[-1]+line.strip()

	if pr:
		if not os.path.exists(outdir+"/"+str(printcount).zfill(4)):
			os.mkdir(outdir+"/"+str(printcount).zfill(4))
		fh = open(outdir+"/"+str(printcount).zfill(4)+"/p0001", 'w')

#		print("%s\t%s" %(str(printcount).zfill(4), cum_length+len(seqs[-1])))
		for j in range(len(headers)):
			fh.write("%s\n%s\n" %(headers[j],seqs[j]))
		fh.close()

	if not pr:
		return printcount

unitdict = {}
print("Counting partitions (batchsize >= "+str(n)+"bp, minimum length = "+str(min)+"bp) ..")
for sample in samples.index.values.tolist():
    print("\t"+sample+" - n=", end='')
    count = subprocess.run("bash ./bin/count_length.sh %s %i %i count" %(samples.fasta[sample], n, min), shell=True, stdout=subprocess.PIPE)
    counter = int(count.stdout.decode('utf-8').split("\t")[-1])


#    counter=partition_by_length(str(samples.fasta[sample]), max_length=n, min_length=min, pr=0) 
    print(counter)
    print("\t"+count.stdout.decode('utf-8').split("\t")[0])
    unitdict[sample] = []
    for i in range(1,counter+1):
        dic['sample'].append(sample)
        dic['unit'].append(str(i).zfill(4))
	unitdict[sample].append(str(i).zfill(4))	
	
#print(unitdict)
##print dic

units = pd.DataFrame(dic).set_index(['sample','unit'], drop=False)
#print(units)
#print(units.index.tolist())
#print units
#for row in units.itertuples():
#    print(row)

units.index.names = ["sample_id", "unit_id"]
units.index = units.index.set_levels(
    [i.astype(str) for i in units.index.levels])  # enforce str in index
