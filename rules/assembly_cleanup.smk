##if config["clean"]["run"]:

def determine_fcs_adaptor_input(wildcards):
	inputfiles = []
	if config["assembly_cleanup"]["run_funannotate_clean"]:
		inputfiles.append("results/" + wildcards.sample + "/ASSEMBLY_CLEANUP/" + wildcards.sample + "_cleaned.funannotate.fas")	
	else:
		inputfiles.append("results/" + wildcards.sample + "/ASSEMBLY_CLEANUP/" + wildcards.sample + "_cleaned.simple.fas")	
	return inputfiles

def determine_fcs_foreign_input(wildcards):
	inputfiles = []
	if config["assembly_cleanup"]["run_ncbi_adaptor_screen"]:
		inputfiles.append("results/" + wildcards.sample + "/ASSEMBLY_CLEANUP/FCS-ADAPTOR/" + wildcards.sample + "_cleaned.fcs.adaptor.fas")	
	elif config["assembly_cleanup"]["run_funannotate_clean"]:
		inputfiles.append("results/" + wildcards.sample + "/ASSEMBLY_CLEANUP/" + wildcards.sample + "_cleaned.funannotate.fas")	
	else:
		inputfiles.append("results/" + wildcards.sample + "/ASSEMBLY_CLEANUP/" + wildcards.sample + "_cleaned.simple.fas")	
	return inputfiles

def determine_sort_input(wildcards):
	inputfiles = []
	if config["assembly_cleanup"]["run_ncbi_foreign_sequences_screen"]: # the order of these ifs is important!
		inputfiles.append("results/" + wildcards.sample + "/ASSEMBLY_CLEANUP/FCS-FOREIGNSEQS/" + wildcards.sample + "_cleaned.fcs.foreignseqs.fas")	
	elif config["assembly_cleanup"]["run_ncbi_adaptor_screen"]:
		inputfiles.append("results/" + wildcards.sample + "/ASSEMBLY_CLEANUP/FCS-ADAPTOR/" + wildcards.sample + "_cleaned.fcs.adaptor.fas")	
	elif config["assembly_cleanup"]["run_funannotate_clean"]:
		inputfiles.append("results/" + wildcards.sample + "/ASSEMBLY_CLEANUP/" + wildcards.sample + "_cleaned.funannotate.fas")	
	else:
		inputfiles.append("results/" + wildcards.sample + "/ASSEMBLY_CLEANUP/" + wildcards.sample + "_cleaned.simple.fas")	
	return inputfiles

def get_taxid(wildcards):
	print(sample_data.loc[wildcards.sample])
	taxid = sample_data.loc[wildcards.sample, "taxid"]
	print("My TAXID:", taxid, "for", wildcards.sample)
	if not taxid:
		print("ERROR: No taxid provided for", wildcards.sample, ". CHECK MANUALLY")
		sys.exit(1)
	try: #need to check if provided taxid is a number
		taxid = int(taxid)
	except ValueError:
		print("ERROR: No taxid provided for", wildcards.sample, " can not be interpreted. CHECK MANUALLY")
		sys.exit(1)
	return taxid
		
def get_assembly_path(wildcards):
	# this is to get the assembly path information for the sample from the CSV file
	pathlist = []
	#quick check if path is absolute. if not make it absolute
	for path in sample_data.loc[wildcards.sample, ["assembly_path"]].to_list():
		if os.path.isabs(path):
			pathlist.append(path)
		else:
			pathlist.append(os.path.abspath(path))	
	return pathlist

rule funannotate_clean:
	input:
		assembly = get_assembly_path
	output:
		assembly ="results/{sample}/ASSEMBLY_CLEANUP/{sample}_cleaned.funannotate.fas",
		ok = "checkpoints/{sample}/clean.ok"
	shadow: "shallow"
	log:
		"results/{sample}/logs/clean.{sample}.log"
	params:
		folder = "{sample}",
		minlen = config["assembly_cleanup"]["minlen"],
		wd = os.getcwd()
	threads: 1
	singularity:
		config["containers"]["funannotate"]
	shell:
		"""
		funannotate clean -i {input.assembly} -o {output.assembly} --minlen {params.minlen} &> {log}
		touch {output.ok}
		"""

rule simple_clean:
	input:
		assembly = get_assembly_path
	output:
		assembly ="results/{sample}/ASSEMBLY_CLEANUP/{sample}_cleaned.simple.fas",
		ok = "checkpoints/{sample}/clean.ok"
	shadow: "shallow"
	log:
		"results/{sample}/logs/clean.{sample}.log"
	params:
		folder = "{sample}",
		minlen = config["assembly_cleanup"]["minlen"],
		wd = os.getcwd(),
		ns = config["assembly_cleanup"]["percent_ns"],
		script = "bin/lengthfilter.py"
	threads: 1
	singularity:
		config["containers"]["funannotate"] # a different (smaller) container could be used here.
	shell:
		"""
		{params.script} {input.assembly} {params.minlen} {params.ns} > {output.assembly}
		touch {output.ok}
		"""

rule fcs_adaptor:
	input:
		assembly = determine_fcs_adaptor_input
	output:
		assembly ="results/{sample}/ASSEMBLY_CLEANUP/FCS-ADAPTOR/{sample}_cleaned.fcs.adaptor.fas"			
	log:
		"results/{sample}/logs/fcs_adaptor.{sample}.log"
	container: "docker://ncbi/fcs-adaptor:0.2.3"
	shell:
		"""
		/app/fcs/bin/av_screen_x -o results/{wildcards.sample}/ASSEMBLY_CLEANUP/FCS-ADAPTOR/ --euk {input.assembly}
		ln -s $(pwd)/results/{wildcards.sample}/ASSEMBLY_CLEANUP/FCS-ADAPTOR/cleaned_sequences/$(basename {input}) {output.assembly}
		"""

rule fcs_foreign:
	input:
		assembly = determine_fcs_foreign_input
	output:
		report = "results/{sample}/ASSEMBLY_CLEANUP/FCS-FOREIGNSEQS/{sample}_fcsgx.txt"
	params:
		taxid = get_taxid,
		whichdb = config["assembly_cleanup"]["contaminant_database"] 
	log:
		"results/{sample}/logs/fcs_foreign_sequences.{sample}.log"
	container: "docker://ncbi/fcs-gx:0.2.3"
		
	shell:
		"""
		python3 /app/bin/run_gx --fasta {input.assembly} --out-dir $(dirname {output.report}) --gx-db $(pwd)/data/ncbi-fcs-db/db/{params.whichdb} --tax-id {params.taxid}  --split-fasta=T &> {log}
		cp $(find $(dirname {output.report})/*_report.txt) {output.report}
		"""

rule fcs_foreign_apply_filter:
	input:
		report = rules.fcs_foreign.output.report,
		assembly = determine_fcs_foreign_input	
	output:
		assembly = "results/{sample}/ASSEMBLY_CLEANUP/FCS-FOREIGNSEQS/{sample}_cleaned.fcs.foreignseqs.fas"
	params:
		settings = config["assembly_cleanup"]["ncbi_foreign_sequences_parameters"]
	log:
		"results/{sample}/logs/fcs_foreign_apply_filter.{sample}.log"
	container:	
		"docker://reslp/biopython_plus:1.77"
	shell:
		"""
		bin/contaminant-removal.py -a {input.assembly} -c {input.report} {params.settings} 1> {output.assembly} 2> {log}
		ln -s $(pwd)/results/{wildcards.sample}/ASSEMBLY_CLEANUP/FCS-FOREIGNSEQS/{wildcards.sample}_cleaned.fcs.foreignseqs.fas $(pwd)/results/{wildcards.sample}/ASSEMBLY_CLEANUP/{wildcards.sample}.cleaned.fcs.foreinseqs.fas
		"""

#  $SHM_LOC/local/{params.whichdb} --gx-db-disk $SHM_LOC
# 'singularity', 'exec', '--bind', '/cl_tmp/reslph/projects/annocomba-monos/fcs-gx-test/disk/gxdb:/app/db/gxdb', '--bind', '/cl_tmp/reslph/projects/annocomba-monos/fcs-gx-test:/sample-volume/', '--bind', '/cl_tmp/reslph/projects/annocomba-monos/fcs-gx-test/gx_out:/output-volume/', 'fcsgx.sif', 'python3', '/app/bin/run_gx', '--fasta', '/sample-volume/fcsgx_test.fa.gz', '--out-dir', '/output-volume/', '--gx-db', '/app/db/gxdb/test-only', '--tax-id', '6973', '--split-fasta=T'

rule sort:
	input:
#		assembly = rules.clean.output.assembly
		assembly = determine_sort_input
	output:
		assembly = "results/{sample}/ASSEMBLY_CLEANUP/{sample}_sorted.fas",
		ok = "checkpoints/{sample}/sort.ok"
	log:
		"results/{sample}/logs/sort.{sample}.log"
	params:
		folder = "{sample}",
		contig_prefix = get_contig_prefix,
		wd = os.getcwd()
	threads: 1
	singularity:
		config["containers"]["funannotate"]
	shell:
		"""
		funannotate sort -i {input.assembly} -o {output.assembly} -b {params.contig_prefix} &> {log}
		touch {output.ok}
		"""
#else:
#        rule sort:
#        	input:
#        		assembly = get_assembly_path
#        	output:
#        		full_assembly = "results/{sample}/{sample}_sorted.all.fas",
#			assembly = "results/{sample}/{sample}_sorted.fas",
#        		ok = "checkpoints/{sample}/sort.ok"
#        	log:
#        		"results/{sample}/logs/clean.{sample}.log"
#        	params:
#        		folder = "{sample}",
#        		contig_prefix = get_contig_prefix,
#        		wd = os.getcwd(),
#                        minlen = config["clean"]["minlen"],
#			script = "bin/lengthfilter.py"
#        	threads: 1
#        	singularity:
#        		config["containers"]["funannotate"]
#        	shell:
#        		"""
#                       funannotate sort -i {input.assembly} -o {output.full_assembly} -b {params.contig_prefix} &> {log}
#        		{params.script} {output.full_assembly} {params.minlen} > {output.assembly}
#        		touch {output.ok}
#        		"""

#rule gather_assembly_cleanup:
#	input:
#		determine_cleanup_input
#	output:
#		assembly = "results/{sample}/{sample}_sorted.fas"	
#	shell:
#		"""
#		touch {output}
#		"""
