rule iprscan:
	input:
		predict_ok = rules.predict.output,
		proteins = "results/{sample}/FUNANNOTATE/{contig_prefix}_preds/predict_results/{sample}.proteins.fa"
	params:
		folder="{sample}",
		pred_folder = "{contig_prefix}",
		iprscan=config["iprscan"],
		wd = os.getcwd()
	singularity:
		config["containers"]["funannotate"]
	log:
		"results/{sample}/logs/ipscan.{contig_prefix}.log"
	output:
		check = "checkpoints/{sample}/iprscan.{contig_prefix}.done",
		xml = "results/{sample}/FUNANNOTATE/{contig_prefix}_preds/annotate_misc/iprscan.xml"
	shadow: "shallow"
	shell:
		"""
		mkdir -p {params.pred_folder}_preds/annotate_misc
		#funannotate iprscan --iprscan_path /data/external/interproscan-5.33-72.0/interproscan.sh -i ../../results/{params.folder}/{params.pred_folder}_preds -m local -c 2 >& ../../{log}
		{params.iprscan} -i {input.proteins} -o {output.xml} -f XML -goterms -pa >& {log}
		touch {output.check}
		"""
rule remote:
	input:
		rules.predict.output
	output:
		"checkpoints/{sample}/FUNANNOTATE_remote.{contig_prefix}.done"
	params:
		folder="{sample}",
		pred_folder = "{contig_prefix}",
		methods = config["remote"]["methods"],
		email = config["remote"]["email"]
	log:
		"results/{sample}/logs/remote.{contig_prefix}.log"
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
		"checkpoints/{sample}/eggnog.{contig_prefix}.done"
	params:
		folder="{sample}",
		pred_folder = "{contig_prefix}",
	log:
		"results/{sample}/logs/eggnog.{contig_prefix}.log"
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
		"checkpoints/{sample}/get_functions.{contig_prefix}.done"
	shell:
		"""
		touch {output}
		"""

