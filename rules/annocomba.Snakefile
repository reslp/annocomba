#singularity: "docker://reslp/funannotate:1.7.2"

include: "annocomba.callgenes.Snakefile"
rule annotate_all:
	input:
		determine_annotations()

include: "funannotate_sort_mask.smk"
include: "maker_part_one.smk"
include: "repeats.smk"
include: "maker_post_repeats.smk"
include: "funannotate_predict.smk"
include: "get_functions.smk"
include: "funannotate_final_steps.smk"

