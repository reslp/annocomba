rule split_proteins:
	input:
		checkpoint = rules.aggregate_funannotate_predict.output
	output:
		dir = directory("results/{sample}/INTERPROSCAN/protein_batches"),
		checkpoint = "checkpoints/{sample}/split_proteins.ok",
	singularity:
		config["containers"]["funannotate"]
	params:
		n_batches = get_batch_number,
		wd = os.getcwd(),
		contig_prefix = get_contig_prefix
	shell:
		"""
		mkdir {output.dir}
		cd {output.dir}

		{params.wd}/bin/split_fasta.py {params.wd}/results/{wildcards.sample}/FUNANNOTATE/{params.contig_prefix}_preds/predict_results/{sample}.proteins.fa {params.n_batches}

		touch {params.wd}/{output.checkpoint}
		"""
rule iprscan:
	input:
		checkpoint = rules.split_proteins.output,
		protein_batch_file = "results/{sample}/INTERPROSCAN/protein_batches/{batch}.fasta"
	params:
		folder="{sample}",
		pred_folder = get_contig_prefix,
		iprscan=config["iprscan"],
		wd = os.getcwd()
	singularity:
		config["containers"]["interproscan"]
	log:
		"results/{sample}/logs/ipscan.{batch}.log"
	output:
		check = "checkpoints/{sample}/iprscan.{batch}.done",
		outxml = "results/{sample}/INTERPROSCAN/output_xmls/{batch}.xml"
	threads: config["threads"]["interproscan"]
	shell:
		"""
		{params.iprscan} -cpu {threads} -i {input.protein_batch_file} -o {output.outxml} -f XML -goterms -pa 2>&1 | tee {log}
		touch {output.check}
		"""
# this should be moved to utilities or functions.smk:
def get_iprbatches(wildcards):
	file_list = []
	for batch in range(1,int(get_batch_number(wildcards)[0])+1):
		file_list.append("results/" + wildcards.sample + "/INTERPROSCAN/output_xmls/" + "%04d.xml" % batch)
	return file_list


rule aggregate_iprscan:
	input:
		get_iprbatches
	output:
		"checkpoints/{sample}/aggregate_INTERPROSCAN.done"
	params:
		pred_folder = get_contig_prefix
	shell:
		"""
		mkdir -p results/{wildcards.sample}/FUNANNOTATE/{params.pred_folder}_preds/annotate_misc
		head -n 1 {input[0]} > results/{wildcards.sample}/FUNANNOTATE/{params.pred_folder}_preds/annotate_misc/iprscan.xml
		for f in "{input}"; do cat $f | tail -n +2 | head -n -1; done >> results/{wildcards.sample}/FUNANNOTATE/{params.pred_folder}_preds/annotate_misc/iprscan.xml
		tail -n 1 {input[0]} >> results/{wildcards.sample}/FUNANNOTATE/{params.pred_folder}_preds/annotate_misc/iprscan.xml
		touch {output}
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

