#singularity: "docker://reslp/funannotate:1.7.2"

include: "annocomba.callgenes.Snakefile"
include: "get_functions.smk"
include: "funannotate_final_steps.smk"

rule annotate:
	input:
		determine_annotations()
	singularity:
		"docker://nextgenusfs/funannotate:v1.8.17"
#		config["containers"]["funannotate"]
	output:
		"checkpoints/{sample}/funannotate_annotate.done"
	params:
		sample = "{sample}",
		wd = os.getcwd(),
		pred_folder = get_contig_prefix,
		to_annotate = config["to_annotate"],
		buscodb = config["funannotate_busco_set"]
	threads: config["annotate"]["threads"]
	log:
		"results/{sample}/logs/funannotate_annotate.log"
	shell:
		"""
		cd results/{params.sample}/{params.to_annotate}
		funannotate annotate -i {params.sample}_preds --eggnog {params.sample}_preds/eggnog_results.emapper.annotations -d /data/database --busco_db {params.buscodb} --iprscan {params.sample}_preds/annotate_misc/iprscan.xml --cpus {threads} >& {params.wd}/{log}
#		funannotate annotate -i {params.sample}_preds --sbt {params.wd}/data/monogenea-template.sbt $(if [ -f {params.sample}_preds/eggnog_results.emapper.annotations ]; then echo "--eggnog {params.sample}_preds/eggnog_results.emapper.annotations --busco_db {params.buscodb}"; fi) --cpus {threads} >& {params.wd}/{log}
		touch {params.wd}/{output}
		"""
		
rule annotate_all:
	input:
		expand("checkpoints/{s}/funannotate_annotate.done", s=get_sample_selection())
	

