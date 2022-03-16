rule split_proteins:
	input:
		proteins = rules.predict.output.proteins
	output:
		dir = directory("results/{sample}/PROTEIN_PARTITIONS_{contig_prefix}"),
		checkpoint = "checkpoints/{sample}/split_proteins.{contig_prefix}.ok",
	singularity:
		config["containers"]["funannotate"]
	params:
		n_batches = get_batch_number,
		wd = os.getcwd(),
	shell:
		"""
		mkdir {output.dir}
		cd {output.dir}

		{params.wd}/bin/split_fasta.py {params.wd}/{input.proteins} {params.n_batches}

		touch {params.wd}/{output.checkpoint}
		"""
rule iprscan:
	input:
#		predict_ok = rules.predict.output,
		prots = rules.split_proteins.output,
#		proteins = "results/{sample}/FUNANNOTATE/{contig_prefix}_preds/predict_results/{sample}.proteins.fa"
	params:
		folder="{sample}",
		pred_folder = "{contig_prefix}",
		iprscan=config["iprscan"],
		wd = os.getcwd()
	singularity:
		config["containers"]["interproscan"]
	log:
		"results/{sample}/logs/ipscan.{contig_prefix}.log"
	output:
		check = "checkpoints/{sample}/iprscan.{contig_prefix}.done",
		outdir = directory("results/{sample}/FUNANNOTATE/{contig_prefix}_preds/annotate_misc/iprscan_xmls")
#		xml = "results/{sample}/FUNANNOTATE/{contig_prefix}_preds/annotate_misc/iprscan.xml"
	threads: config["threads"]["interproscan"]
	shadow: "minimal"
	shell:
		"""
		mkdir -p {output.outdir}
		for f in $(ls -1 results/{wildcards.sample}/PROTEIN_PARTITIONS_{wildcards.contig_prefix}/*.fasta)
		do
			echo -e "\n[$(date)] - processing $f"
			{params.iprscan} -cpu {threads} -i $f -o {output.outdir}/$(basename $f | sed 's/.fasta$/.xml/') -f XML -goterms -pa 
			echo -e "\n[$(date)] - Done!"
			
		done 2>&1 | tee {log}
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
		sample="{sample}",
		pred_folder = "{contig_prefix}",
		wd = os.getcwd()
	log:
		"results/{sample}/logs/eggnog.{contig_prefix}.log"
	singularity:
		"docker://reslp/eggnog-mapper:1.0.3"
	threads: config["eggnog"]["threads"]
	shell:
		"""
		cd results/{params.sample}/FUNANNOTATE
		emapper.py  -i {params.pred_folder}_preds/predict_results/{params.sample}.proteins.fa --output {params.pred_folder}_preds/eggnog_results -d euk --data_dir /data/eggnogdb --cpu {threads} --override -m diamond >& ../../../{log}
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

