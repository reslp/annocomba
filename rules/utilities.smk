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

