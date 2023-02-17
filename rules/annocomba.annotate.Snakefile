#singularity: "docker://reslp/funannotate:1.7.2"

include: "annocomba.callgenes.Snakefile"
include: "get_functions.smk"
include: "funannotate_final_steps.smk"

rule annotate:
	input:
		determine_annotations()
	singularity: "docker://reslp/funannotate:1.8.7"
	output:
		"checkpoints/{sample}/funannotate_annotate.done"
	params:
		sample = "{sample}",
		pred_folder = get_contig_prefix,
		buscodb = config["annotate"]["buscodb"]
	threads: config["annotate"]["threads"]
	log:
		"results/{sample}/logs/funannotate_annotate.log"
	shell:
		"""
		cd results/{params.sample}/FUNANNOTATE
		funannotate annotate -i {params.sample}_preds --sbt ../../../data/monogenea-template.sbt $(if [ -f {params.sample}_preds/eggnog_results.emapper.annotations ]; then echo "--eggnog {params.sample}_preds/eggnog_results.emapper.annotations --busco_db {params.buscodb}"; fi) --cpus {threads} >& ../../../{log}
		touch ../../{output}
		"""
		
rule annotate_all:
	input:
		expand("checkpoints/{s}/funannotate_annotate.done", s=get_sample_selection())
	

