# useful variable definition:
WD=os.getcwd()
email="philipp.resl@uni-graz.at"

#sample_data = pd.read_table(config["samples"]).set_index("sample", drop=False)
def get_assembly_path(wildcards):
# this is to get the assembly path information for the sample from the CSV file
        return sample_data.loc[wildcards.sample, ["assembly_path"]].to_list()

def get_contig_prefix(wildcards):
        return sample_data.loc[wildcards.sample, ["contig_prefix"]].to_list()

def get_premasked_state(wildcards):
        return sample_data.loc[wildcards.sample, ["premasked"]].to_list()[-1]

def get_all_samples(wildcards):
        sam = sample_data["contig_prefix"].tolist()
        sam = [sample+"s" for sample in sam].join()
        return sam

def get_batch_number(wildcards):
	return sample_data.loc[wildcards.sample, ["batches"]].to_list()

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

