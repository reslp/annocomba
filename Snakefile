#singularity: "docker://reslp/funannotate:1.7.2"

import pandas as pd
import os

configfile: "data/config.yaml"
sample_data = pd.read_table(config["samples"], header=0, delim_whitespace=True).set_index("sample", drop=False)

include: "rules/utilities.smk"

rule all:
	input:
#		expand("results/{name}/{name}_cleaned.fas", name=sample_data.index.tolist()),
		expand("results/{name}/{name}_sorted.fas", name=sample_data.index.tolist()),
		expand("checkpoints/{name}/split.ok", name= sample_data.index.tolist()),
		expand("checkpoints/{name}/genemark.status.ok", name=sample_data.index.tolist()),
		expand("checkpoints/{name}/busco.status.ok", name=sample_data.index.tolist()),
		expand("checkpoints/{name}/cegma.status.ok", name=sample_data.index.tolist()),
		expand("checkpoints/{name}/repeatmodeler.status.ok", name=sample_data.index.tolist()),
		expand("checkpoints/{name}/repeatmasker.denovo.status.ok", name=sample_data.index.tolist()),
		expand("checkpoints/{name}/repeatmasker.full.status.ok", name=sample_data.index.tolist()),
		expand("checkpoints/{name}/MAKER_PASS1_init.ok", name=sample_data.index.tolist()),	
#		expand("results/{unit.sample}/MAKER.PASS1/{unit.unit}/{unit.sample}.{unit.unit}.maker.output.tar.gz", unit=units.itertuples()),
		expand("checkpoints/{name}/merge_MAKER_PASS1.ok", name=sample_data.index.tolist()),
		expand("checkpoints/{name}/MAKER.PASS2.init.ok", name=sample_data.index.tolist()),
		expand("results/{name}/MAKER.PASS2/{name}.all.maker.gff", name=sample_data.index.tolist()),
#		expand("results/{unit.sample}/MAKER.PASS2/{unit.unit}/{unit.sample}.{unit.unit}.maker.output.tar.gz", unit=units.itertuples()),
		expand("checkpoints/{name.sample}/FUNANNOTATE_tarpredict.{name.contig_prefix}.done", name=sample_prefix_units.itertuples()),
		expand("checkpoints/{name.sample}/get_functions.{name.contig_prefix}.done", name=sample_prefix_units.itertuples()),
		expand("checkpoints/{name.sample}/FUNANNOTATE_annotate.{name.contig_prefix}.done", name=sample_prefix_units.itertuples()),
		"checkpoints/FUNANNOTATE_compare.done"

include: "rules/setup_maker.smk"
include: "rules/setup_funannotate.smk"
include: "rules/setup_eggnog.smk"
include: "rules/funannotate_sort_mask.smk"
include: "rules/maker_part_one.smk"
include: "rules/repeats.smk"
include: "rules/maker_post_repeats.smk"
include: "rules/funannotate_predict.smk"
include: "rules/funannotate_get_functions.smk"
include: "rules/funannotate_final_steps.smk"

