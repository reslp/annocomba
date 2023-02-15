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

		{params.wd}/bin/split_fasta.py {params.wd}/results/{wildcards.sample}/FUNANNOTATE/{wildcards.sample}_preds/predict_results/{wildcards.sample}.proteins.fa {params.n_batches}

		touch {params.wd}/{output.checkpoint}
		"""

rule interproscan:
	input:
		checkpoint = rules.split_proteins.output,
	params:
		folder="{sample}",
		pred_folder = get_contig_prefix,
		iprscan=config["iprscan"],
		wd = os.getcwd(),
		protein_batch_file = "results/{sample}/INTERPROSCAN/protein_batches/{batch}.fasta"
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
		# this now expects that data/external/interproscan exists
		data/external/interproscan/interproscan.sh -cpu {threads} -i {params.protein_batch_file} -o {output.outxml} -f XML -goterms -pa 2>&1 | tee {log}
		touch {output.check}
		"""

# this should be moved to utilities or functions.smk:
def get_iprbatches(wildcards):
	file_list = []
	for batch in range(1,int(get_batch_number(wildcards)[0])+1):
		file_list.append("results/" + wildcards.sample + "/INTERPROSCAN/output_xmls/" + "%04d.xml" % batch)
	return file_list


rule gather_iprscan:
	input:
		get_iprbatches
	output:
		"checkpoints/{sample}/aggregate_INTERPROSCAN.done"
	params:
		pred_folder = get_contig_prefix
	singularity:
		config["containers"]["interproscan"]
	shell:
		"""
		mkdir -p results/{wildcards.sample}/FUNANNOTATE/{wildcards.sample}_preds/annotate_misc
		head -n 1 {input[0]} > results/{wildcards.sample}/FUNANNOTATE/{wildcards.sample}_preds/annotate_misc/iprscan.xml
		for f in $(echo "{input}"); do cat $f | tail -n +2 | head -n -1; done >> results/{wildcards.sample}/FUNANNOTATE/{wildcards.sample}_preds/annotate_misc/iprscan.xml
		tail -n 1 {input[0]} >> results/{wildcards.sample}/FUNANNOTATE/{wildcards.sample}_preds/annotate_misc/iprscan.xml

		for f in $(echo "{input}"); do echo $f; data/external/interproscan/interproscan.sh -m convert -i $f -o results/{wildcards.sample}/INTERPROSCAN/output_xmls/$(basename "$f" .xml).tsv -f TSV; done
		cat results/{wildcards.sample}/INTERPROSCAN/output_xmls/*.tsv > results/{wildcards.sample}/INTERPROSCAN/{wildcards.sample}_interproscan.tsv
		touch {output}
		"""
rule remote:
	input:
		rules.aggregate_funannotate_predict.output
	output:
		"checkpoints/{sample}/FUNANNOTATE_remote.done"
	params:
		folder="{sample}",
		pred_folder = get_contig_prefix,
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
		rules.aggregate_funannotate_predict.output
	output:
		"checkpoints/{sample}/eggnog.done"
	params:
		sample="{sample}",
		pred_folder = get_contig_prefix,
		wd = os.getcwd()
	log:
		"results/{sample}/logs/eggnog.log"
	singularity:
		"docker://reslp/eggnog-mapper:1.0.3"
	threads: config["eggnog"]["threads"]
	shell:
		"""
		cd results/{params.sample}/FUNANNOTATE
		emapper.py  -i {params.sample}_preds/predict_results/{params.sample}.proteins.fa --output {params.sample}_preds/eggnog_results -d euk --data_dir /data/eggnogdb --cpu {threads} --override -m diamond >& ../../../{log}
		touch ../../../{output}
		"""

rule prepare_assembly:
	input: 
		assembly = get_assembly_path
	output:
		reformatted_assembly = "results/{sample}/{sample}.assembly.fa"
	params:
		sp = "{sample}",
		prefix = get_contig_prefix
	singularity:
		"docker://reslp/biopython_plus:1.77"
	shell:
		"""
		#all seqs upper case
		cat {input.assembly} | awk '{{if ($1 ~ /^>/) {{print $1}} else {{print toupper($1)}}}}' > results/{params.sp}/assembly_tmp.fa
		#shorten names
		python bin/rename_contigs.py results/{params.sp}/assembly_tmp.fa {params.prefix} > {output.reformatted_assembly}
		"""

rule edta:
	input: 
		assembly = rules.prepare_assembly.output.reformatted_assembly
	output:
		check = "checkpoints/{sample}/EDTA.done"
	params:
		args = get_edta_parameters, # at the moment this returns an empty string
		add_args = "--overwrite 1 --anno 1 --force 1",
		sp = "{sample}"
	log:
		"results/{sample}/logs/{sample}_edta.log"
	shadow:
		"shallow"
	singularity:
		"docker://reslp/edta:2.0.1"	
	threads: config["threads"]["edta"]
	shell:
		"""
		export LC_ALL=C
		
		EDTA.pl --genome {input.assembly} {params.add_args} {params.args} --threads {threads} &> {log}
		
		#copy output to results folder
		mkdir -p results/{params.sp}/EDTA
		cp -rf ./{params.sp}* results/{params.sp}/EDTA
		touch {output.check}
		"""

rule get_functions_all:
	input:
		expand("checkpoints/{sample}/aggregate_INTERPROSCAN.done", sample=get_sample_selection()),
		expand("checkpoints/{sample}/remote.done", sample=get_sample_selection()),
		expand("checkpoints/{sample}/eggnog.done", sample=get_sample_selection())
	output:
		"checkpoints/{sample}/get_functions.all.done"
	shell:
		"""
		touch {output}
		"""

rule get_functions_interproscan:
	input:
		expand("checkpoints/{sample}/aggregate_INTERPROSCAN.done", sample=get_sample_selection())
	output:
		"checkpoints/get_functions.interproscan.done"
	shell:
		"""
		touch {output}
		"""

rule get_functions_remote:
	input:
		expand("checkpoints/{sample}/FUNANNOTATE_remote.done", sample=get_sample_selection())
	output:
		"checkpoints/get_functions.remote.done"
	shell:
		"""
		touch {output}
		"""

rule get_functions_eggnog:
	input:
		expand("checkpoints/{sample}/eggnog.done", sample=get_sample_selection())
	output:
		"checkpoints/get_functions.eggnog.done"
	shell:
		"""
		touch {output}
		"""
