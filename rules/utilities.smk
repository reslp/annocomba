import pandas as pd
import os
import glob
from math import ceil
from pathlib import Path
from subprocess import call

configfile: "data/config.yaml"
sample_data = pd.read_table(config["samples"], header=0, delim_whitespace=True).set_index("sample", drop=False)

# useful variable definition:
WD=os.getcwd()

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

def get_transcripts_path(wildcards):
	#get paths to fasta transcript fasta files - if file has prefix identical to sample prefix in data.csv -> assume it's a transcriptome of this species -> MAKER 'est' option
	dic = {'alt_ests': [], 'ests': []}
	# this is the old behavior with a single folder, but now it can be specified in the config.yaml file:
	for f in glob.glob(config["est_evidence_path"]+"/"+sample+"/*"):
		if f.endswith(".fasta") or f.endswith(".fa") or f.endswith(".fas"):
			if f.split("/")[-1].startswith(wildcards.sample):
				print(f+"-> fasta - target species est evidence")
				dic['ests'].append(os.path.abspath(f))
			else:
				print(f+"-> fasta - alternative species est evidence")
				dic['alt_ests'].append(os.path.abspath(f))
	# on top of that let's check for transcript evidence in the samples file:
	which_est = sample_data.loc[wildcards.sample, ["est_type"]].to_list()[0]
	est_path = sample_data.loc[wildcards.sample, ["est_path"]].to_list()[0]
	if not pd.isna(which_est) or not pd.isna(est_path):
		for est_file, w_est in zip(est_path.split(","), which_est): # allow multiple files as est specified in tsv file seperated by commas.
			if os.path.isfile(est_file):
				if w_est == "species":
					print("\tWill use", est_file, "as species specific EST evidence")
					dic['ests'].append(os.path.abspath(est_file))
				if w_est == "other":
					print("\tWill use", est_file, "as alternative EST evidence")
					dic['alt_ests'].append(os.path.abspath(est_file))
			else:
				print("\tEST file:", est_file, " specified in samples TSV file not found! Thus it will not be used. Please check!")
	else:
		print("\t" + sample + ": EST evidence in " + config["samples"] + " not specified.")
	# now remove redundant files in case there are any:
	dic["alt_ests"] = list(dict.fromkeys(dic["alt_ests"] ))
	dic["ests"] = list(dict.fromkeys(dic["ests"] ))

#	print(str(dic))
	return dic


print("Checking for EST evidence files (eg. transcriptome assemblies) per sample:")
for sample in sample_data.index.values.tolist():
	for f in glob.glob(config["est_evidence_path"]+"/"+sample+"/*"):
		if f.endswith(".fasta") or f.endswith(".fa") or f.endswith(".fas"):
			if f.split("/")[-1].startswith(sample):
				print("\t" + sample + ": " + f + "-> fasta - target species est evidence in " + config["est_evidence_path"])
			else:
				print("\t" + sample + ": " + f + "-> fasta - alternative species est evidence in "+ config["est_evidence_path"])
	which_est = sample_data.loc[sample, ["est_type"]].to_list()[0]
	est_path = sample_data.loc[sample, ["est_path"]].to_list()[0]
	if not pd.isna(which_est) or not pd.isna(est_path):
		for est_file, w_est in zip(est_path.split(","), which_est.split(",")): # allow multiple files as est specified in tsv file seperated by commas.
			if os.path.isfile(est_file):
				if w_est == "species":
					print("\t","Will use", est_file, "as species specific EST evidence")
				if w_est == "other":
					print("\t", "Will use", est_file, "as alternative EST evidence")
			else:
				print("\t","EST file:", est_file, " specified in samples TSV file not found! Thus it will not be used. Please check!")
	else:
		print("\t" + sample + ": EST evidence in " + config["samples"] + " not specified.")

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

