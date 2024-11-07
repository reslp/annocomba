rule braker_protein:
	input:
		assembly = rules.mask_repeats.output.soft,
		protein_evidence = "results/{sample}/NR_PROTEIN_EVIDENCE/nr_external_proteins.cd-hit.fasta",
		gm_gtf = rules.genemark.output.gtf 
	output:
		ok = "results/{sample}/BRAKER-PROTEIN/braker.ok"
	params:
		wd = os.getcwd(),
		optional = config["braker"]["additional_params"],
		busco_lineage = config["busco_set"]
	log:
		"results/{sample}/logs/BRAKER-PROTEIN.log" 
	singularity: config["containers"]["braker"]
	threads: config["braker"]["threads"] 
	shell:
		"""
		cd results/{wildcards.sample}/BRAKER-PROTEIN

		if [[ -d augustus ]]; then rm -rf augustus; fi
		mkdir augustus
		cp -r /opt/Augustus/config augustus/
		export AUGUSTUS_CONFIG_PATH={params.wd}/results/{wildcards.sample}/BRAKER-PROTEIN/augustus/config/

		braker.pl \
			--species={wildcards.sample} \
			--genome={params.wd}/{input.assembly} \
			--prot_seq={params.wd}/{input.protein_evidence} \
			--workingdir={params.wd}/results/{wildcards.sample}/BRAKER-PROTEIN \
			--threads {threads} \
			--busco_lineage {params.busco_lineage} \
			--skipGeneMark-ES --geneMarkGtf={params.wd}/{input.gm_gtf} \
			$(if [[ "{params.optional}" != "None" ]]; then echo -n "{params.optional}"; fi) 2>&1 | tee {params.wd}/{log} 
		#clean up some
		echo -e "\n\n[$(date)]\tCleaning up:" >> {params.wd}/{log}
		for d in $(find ./ -maxdepth 1 -mindepth 1 -type d)
		do
			echo "compressing $d -> $d.tar.gz" >> {params.wd}/{log}
			tar cfz $d.tar.gz $d 2>> {params.wd}/{log} 
			if [[ $? -eq 0 ]]
			then
				echo "removing $d" >> {params.wd}/{log}
				rm -rf $d 2>> {params.wd}/{log}
			fi
		done 

		touch {params.wd}/{output.ok}
		"""

rule braker_prot_rna:
	input:
		assembly = rules.mask_repeats.output.soft,
		protein_evidence = "results/{sample}/NR_PROTEIN_EVIDENCE/nr_external_proteins.cd-hit.fasta",
		gm_gtf = rules.genemark.output.gtf 
	output:
		ok = "results/{sample}/BRAKER-PROT-RNA/braker.ok"
	params:
		wd = os.getcwd(),
		optional = config["braker"]["additional_params"],
		busco_lineage = config["busco_set"],
		rnaseq_sets_dirs = get_rnaseq_dir,
		rnaseq_sets_ids = get_rnaseq_id
	log:
		"results/{sample}/logs/BRAKER-PROT-RNA.log" 
	singularity: config["containers"]["braker"]
	threads: config["braker"]["threads"] 
	shell:
		"""
		cd results/{wildcards.sample}/BRAKER-PROT-RNA

		if [[ -d augustus ]]; then rm -rf augustus; fi
		mkdir augustus
		cp -r /opt/Augustus/config augustus/
		export AUGUSTUS_CONFIG_PATH={params.wd}/results/{wildcards.sample}/BRAKER-PROT-RNA/augustus/config/

		braker.pl \
			--species={wildcards.sample} \
			--genome={params.wd}/{input.assembly} \
			--prot_seq={params.wd}/{input.protein_evidence} \
			--workingdir={params.wd}/results/{wildcards.sample}/BRAKER-PROT-RNA \
			--threads {threads} \
			--busco_lineage {params.busco_lineage} \
			--skipGeneMark-ES --geneMarkGtf={params.wd}/{input.gm_gtf} \
			--rnaseq_sets_ids={params.rnaseq_sets_ids} --rnaseq_sets_dir={params.rnaseq_sets_dirs} \ 
			$(if [[ "{params.optional}" != "None" ]]; then echo -n "{params.optional}"; fi) 2>&1 | tee {params.wd}/{log} 
		#clean up some
		echo -e "\n\n[$(date)]\tCleaning up:" >> {params.wd}/{log}
		for d in $(find ./ -maxdepth 1 -mindepth 1 -type d)
		do
			echo "compressing $d -> $d.tar.gz" >> {params.wd}/{log}
			tar cfz $d.tar.gz $d 2>> {params.wd}/{log} 
			if [[ $? -eq 0 ]]
			then
				echo "removing $d" >> {params.wd}/{log}
				rm -rf $d 2>> {params.wd}/{log}
			fi
		done 

		touch {params.wd}/{output.ok}
		"""
