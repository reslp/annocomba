rule braker_protein:
	input:
		assembly = rules.mask_repeats.output.soft,
		protein_evidence = "results/{sample}/NR_PROTEIN_EVIDENCE/nr_external_proteins.cd-hit.fasta",
		gm_gtf = rules.genemark.output.gtf 
	output:
		ok = "results/{sample}/BRAKER-PROTEIN/braker.ok",
		gff = "results/{sample}/BRAKER-PROTEIN/braker.gff3",
		model = "results/{sample}/BRAKER-PROTEIN/species.tar.gz"
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

		# copy results from initial genemark run
		cp -rf $(dirname {params.wd}/{input.gm_gtf}) GeneMark-ES

		if [[ -d augustus ]]; then rm -rf augustus; fi
		mkdir augustus
		cp -r /opt/Augustus/config augustus/
		export AUGUSTUS_CONFIG_PATH={params.wd}/results/{wildcards.sample}/BRAKER-PROTEIN/augustus/config/

		{params.wd}/bin/braker.pl \
			--species={wildcards.sample} \
			--genome={params.wd}/{input.assembly} \
			--prot_seq={params.wd}/{input.protein_evidence} \
			--workingdir={params.wd}/results/{wildcards.sample}/BRAKER-PROTEIN \
			--AUGUSTUS_ab_initio --gff3 \
			--threads {threads} \
			--nocleanup \
			$(if [[ "{params.optional}" != "None" ]]; then echo -n "{params.optional}"; fi) 2>&1 | tee {params.wd}/{log} 

		##	--busco_lineage {params.busco_lineage} \
		#clean up some
		echo -e "\n\n[$(date)]\tCleaning up:" >> {params.wd}/{log}
		find . -maxdepth 1 -name "aug_ab_initio*" -delete

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

		mkdir temp_files
		mv $(find ./ -mindepth 1 -maxdepth 1 -type f | grep -v "braker." | grep -v "tar.gz$") temp_files/
		tar cvfz temp_files.tar.gz temp_files/
		rm -rf temp_files

		touch {params.wd}/{output.ok}
			#--skipGeneMark-ES \
		"""

rule braker_prot_rna:
	input:
		assembly = rules.mask_repeats.output.soft,
		protein_evidence = "results/{sample}/NR_PROTEIN_EVIDENCE/nr_external_proteins.cd-hit.fasta",
	output:
		ok = "results/{sample}/BRAKER-PROT-RNA/braker.ok",
		gff = "results/{sample}/BRAKER-PROT-RNA/braker.gff3",
		model = "results/{sample}/BRAKER-PROT-RNA/species.tar.gz"
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

		# braker.pl
 
		{params.wd}/bin/braker.pl \
			--species={wildcards.sample} \
			--genome={params.wd}/{input.assembly} \
			--prot_seq={params.wd}/{input.protein_evidence} \
			--workingdir={params.wd}/results/{wildcards.sample}/BRAKER-PROT-RNA \
			--AUGUSTUS_ab_initio --gff3 \
			--threads {threads} \
			--nocleanup \
			--rnaseq_sets_ids={params.rnaseq_sets_ids} --rnaseq_sets_dir={params.rnaseq_sets_dirs} \ 
			$(if [[ "{params.optional}" != "None" ]]; then echo -n "{params.optional}"; fi) 2>&1 | tee {params.wd}/{log} 


		####	--busco_lineage {params.busco_lineage} \
		#clean up some
		echo -e "\n\n[$(date)]\tCleaning up:" >> {params.wd}/{log}
		tar cvfz species.tar.gz species
		find . -maxdepth 1 -name "aug_ab_initio*" -delete

		## remove samfile from hisat
		rm rnaseq/hisat2/*.sam

#		for d in $(find ./ -maxdepth 1 -mindepth 1 -type d)
#		do
#			echo "compressing $d -> $d.tar.gz" >> {params.wd}/{log}
#			{params.wd}/bin/archive.sh $d tar.gz
#		done 
		
#		mkdir temp_files
#		mv $(find ./ -mindepth 1 -maxdepth 1 -type f | grep -v "braker." | grep -v "tar.gz$") temp_files/
#		{params.wd}/bin/archive.sh temp_files tar.gz

		touch {params.wd}/{output.ok}
			#--skipGeneMark-ES \
		"""

rule targz_braker_protein:
	input:
		{rules.braker_protein.output}
	output:
		"checkpoints/{sample}/BRAKER-PROTEIN_targz.done"
	params:
		wd = os.getcwd(),
	shell:
		"""
		cd results/{wildcards.sample}/BRAKER-PROTEIN

		for d in $(find ./ -maxdepth 1 -mindepth 1 -type d)
		do
			echo "compressing $d -> $d.tar.gz" >> {params.wd}/{log}
			{params.wd}/bin/archive.sh $d tar.gz
		done 
		
		mkdir temp_files
		mv $(find ./ -mindepth 1 -maxdepth 1 -type f | grep -v "braker." | grep -v "tar.gz$") temp_files/
		{params.wd}/bin/archive.sh temp_files tar.gz

		touch {params.wd}/{output}
		"""

rule targz_braker_prot_rna:
	input:
		{rules.braker_prot_rna.output}
	output:
		"checkpoints/{sample}/BRAKER-PROT-RNA_targz.done"
	params:
		wd = os.getcwd(),
	shell:
		"""
		cd results/{wildcards.sample}/BRAKER-PROT-RNA

		for d in $(find ./ -maxdepth 1 -mindepth 1 -type d)
		do
			echo "compressing $d -> $d.tar.gz" >> {params.wd}/{log}
			{params.wd}/bin/archive.sh $d tar.gz
		done 
		
		mkdir temp_files
		mv $(find ./ -mindepth 1 -maxdepth 1 -type f | grep -v "braker." | grep -v "tar.gz$") temp_files/
		{params.wd}/bin/archive.sh temp_files tar.gz

		touch {params.wd}/{output}
		"""
