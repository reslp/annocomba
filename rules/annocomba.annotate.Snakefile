#singularity: "docker://reslp/funannotate:1.7.2"

include: "annocomba.callgenes.Snakefile"
include: "get_functions.smk"
include: "funannotate_final_steps.smk"
rule annotate_all:
	input:
		determine_annotations()


