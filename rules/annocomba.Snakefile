#singularity: "docker://reslp/funannotate:1.7.2"

import pandas as pd
import os

configfile: "data/config.yaml"
sample_data = pd.read_table(config["samples"], header=0, delim_whitespace=True).set_index("sample", drop=False)

include: "utilities.smk"

rule all:
	input:
#		expand("results/{name}/{name}_cleaned.fas", name=sample_data.index.tolist()),
		expand("results/{name}/{name}_sorted.fas", name=sample_data.index.tolist()),
		expand("checkpoints/{name}/split.ok", name= sample_data.index.tolist()),
#		expand("checkpoints/{name}/genemark.status.ok", name=sample_data.index.tolist()),
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

rule maker_all:
	input:
		expand("results/{name}/{name}_sorted.fas", name=sample_data.index.tolist()),
                expand("checkpoints/{name}/split.ok", name= sample_data.index.tolist()),
		expand("checkpoints/{name}/busco.status.ok", name=sample_data.index.tolist()),
                expand("checkpoints/{name}/cegma.status.ok", name=sample_data.index.tolist()),
                expand("checkpoints/{name}/repeatmodeler.status.ok", name=sample_data.index.tolist()),
                expand("checkpoints/{name}/repeatmasker.denovo.status.ok", name=sample_data.index.tolist()),
                expand("checkpoints/{name}/repeatmasker.full.status.ok", name=sample_data.index.tolist()),
                expand("checkpoints/{name}/MAKER_PASS1_init.ok", name=sample_data.index.tolist()),
		expand("checkpoints/{name}/merge_MAKER_PASS1.ok", name=sample_data.index.tolist()),
                expand("checkpoints/{name}/MAKER.PASS2.init.ok", name=sample_data.index.tolist()),
                expand("results/{name}/MAKER.PASS2/{name}.all.maker.gff", name=sample_data.index.tolist()),
#		expand("checkpoints/{name.sample}/FUNANNOTATE_tarpredict.{name.contig_prefix}.done", name=sample_prefix_units.itertuples()),	
#		expand("checkpoints/{name.sample}/get_functions.{name.contig_prefix}.done", name=sample_prefix_units.itertuples())

rule funannotate_predict_all:
	input:
		expand("checkpoints/{name.sample}/FUNANNOTATE_tarpredict.{name.contig_prefix}.done", name=sample_prefix_units.itertuples())
#		expand("checkpoints/{name.sample}/get_functions.{name.contig_prefix}.done", name=sample_prefix_units.itertuples())
		

include: "funannotate_sort_mask.smk"
include: "maker_part_one.smk"
include: "repeats.smk"
include: "maker_post_repeats.smk"
include: "funannotate_predict2.smk"
include: "funannotate_get_functions.smk"
include: "funannotate_final_steps.smk"

