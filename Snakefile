singularity: "docker://reslp/funannotate:1.7.2"

import pandas as pd
import os

configfile: "data/config.yaml"
sample_data = pd.read_table(config["samples"], header=0, delim_whitespace=True).set_index("sample", drop=False)

include: "rules/utilities.smk"

rule all:
	input:
		expand("results/{name}/{name}_cleaned.fas", name=sample_data.index.tolist()),
		expand("results/{name}/{name}_sorted.fas", name=sample_data.index.tolist())

include: "rules/setup_maker.smk"
include: "rules/setup_funannotate.smk"
include: "rules/setup_eggnog.smk"
include: "rules/funannotate_sort_mask.smk"

