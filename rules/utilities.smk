import pandas as pd
import os
import glob
from math import ceil
from pathlib import Path
from subprocess import call

# useful variable definition:
WD=os.getcwd()
email="philipp.resl@uni-graz.at"

#sample_data = pd.read_table(config["samples"]).set_index("sample", drop=False)
def get_assembly_path(wildcards):
	# this is to get the assembly path information for the sample from the CSV file
	pathlist = []
	#quick check if path is absolute. if not make it absolute
	for path in sample_data.loc[wildcards.sample, ["assembly_path"]].to_list():
		if os.path.isabs(path):
			pathlist.append(path)
		else:
			pathlist.append(os.path.abspath(path))	
	return pathlist

def get_contig_prefix(wildcards):
	return sample_data.loc[wildcards.sample, ["contig_prefix"]].to_list()

def get_premasked_state(wildcards):
	 sample_data.loc[wildcards.sample, ["premasked"]].to_list()[-1]

def get_all_samples(wildcards):
	sam = sample_data["contig_prefix"].tolist()
	sam = [sample+"s" for sample in sam].join()
	return sam

def get_batch_number(wildcards):
	return sample_data.loc[wildcards.sample, ["batches"]].to_list()

def get_transcripts_path(wildcards, p="data/transcripts/*"):
	#get paths to fasta transcript fasta files - if file has prefix identical to sample prefix in data.csv -> assume it's a transcriptome of this species -> MAKER 'est' option
	dic = {'alt_ests': [], 'ests': []}
	for f in glob.glob(p):
		if f.endswith(".fasta") or f.endswith(".fa") or f.endswith(".fas"):
			print(f+"-> fasta")
			if f.split("/")[-1].startswith(wildcards.sample):
				dic['ests'].append(os.path.abspath(f))
			else:
				dic['alt_ests'].append(os.path.abspath(f))
	return dic


# code to calculate and prepare the number of batches so that snakemake knows how many jobs to spawn
dic = {'sample': [], 'unit': []}
unitdict = {}
print("Counting batches per sample:")
for sample in sample_data.index.values.tolist():
	counter = sample_data.loc[sample, ["batches"]].to_list()
	counter = int(counter.pop())
	print("\t"+sample+" - n="+str(counter))
	unitdict[sample] = []
	for i in range(1,counter+1):
		dic['sample'].append(sample)
		dic['unit'].append(str(i).zfill(4))
		unitdict[sample].append(str(i).zfill(4))
	units = pd.DataFrame(dic).set_index(['sample','unit'], drop=False)

#make dictionary combining the sample names and contig_prefixes
dic = {'sample': [], 'contig_prefix': []}

for sample in set(sample_data.index.values.tolist()):
    contig_prefix = sample_data.loc[sample, ["contig_prefix"]].values[0]
    dic["sample"].append(sample)
    dic["contig_prefix"].append(contig_prefix)

sample_prefix_units = pd.DataFrame(dic).set_index(['sample','contig_prefix'], drop=False)
sample_prefix_units.index = sample_prefix_units.index.set_levels(
    [i.astype(str) for i in sample_prefix_units.index.levels])  # enforce str in index

