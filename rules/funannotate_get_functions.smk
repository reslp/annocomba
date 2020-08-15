rule iprscan:
	input:
		rules.predict.output

	output:
		"checkpoints/{sample}/iprscan.done"
	params:
		folder="{sample}",
		pred_folder=get_contig_prefix,
		version=config["software"]["iprscan_version"]
	singularity:
		config["containers"]["funannotate"]
	log:
		"results/{sample}/logs/ipscan.log"
	shell:
		"""
		cd results/{params.folder}/FUNANNOTATE
		mkdir -p {params.pred_folder}_preds/annotate_misc
		#funannotate iprscan --iprscan_path /data/external/interproscan-5.33-72.0/interproscan.sh -i ../../results/{params.folder}/{params.pred_folder}_preds -m local -c 2 >& ../../{log}
		/data/external/interproscan-{params.version}/interproscan.sh -i ../../../results/{params.folder}/FUNANNOTATE/{params.pred_folder}_preds/predict_results/{params.folder}.proteins.fa -o ../../../results/{params.folder}/FUNANNOTATE/{params.pred_folder}_preds/annotate_misc/iprscan.xml -f XML -goterms -pa >& ../../../{log}
		touch ../../../{output}
		"""
rule remote:
	input:
		rules.predict.output
	output:
		"checkpoints/{sample}/FUNANNOTATE_remote.done"
	params:
		folder="{sample}",
		pred_folder=get_contig_prefix,
		methods = config["remote"]["methods"],
		email = config["remote"]["email"]
	log:
		"results/{sample}/logs/remote.log"
	singularity:
		config["containers"]["funannotate"]
	shell:
		"""
		cd results/{params.folder}/FUNANNOTATE
		funannotate remote -i {params.pred_folder}_preds -m {params.methods} -e {params.email} >& ../../../{log}
		touch ../../../{output}
		"""
rule eggnog:
	input:
		rules.predict.output
	output:
		"checkpoints/{sample}/eggnog.done"
	params:
		folder="{sample}",
		pred_folder=get_contig_prefix
	log:
		"results/{sample}/logs/eggnog.log"
	singularity:
		"docker://reslp/eggnog-mapper:1.0.3"
	threads: config["eggnog"]["threads"]
	shell:
		"""
		cd results/{params.folder}/FUNANNOTATE
		emapper.py  -i {params.pred_folder}_preds/predict_results/{params.folder}.proteins.fa --output {params.pred_folder}_preds/eggnog_results -d euk --data_dir /data/eggnogdb --cpu {threads} --override -m diamond >& ../../../{log}
		touch ../../../{output}
		"""

rule get_functions:
	input:
		rules.eggnog.output,
		rules.iprscan.output,
		rules.remote.output
	output:
		"checkpoints/{sample}/get_functions.done"
	shell:
		"""
		touch {output}
		"""

