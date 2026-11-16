rule funannotate_predict_direct:
	input:
		assembly = rules.mask_repeats.output.soft,
		gm_gtf = rules.genemark.output.gtf,
		protein_evidence = "results/{sample}/NR_PROTEIN_EVIDENCE/nr_external_proteins.cd-hit.fasta" 
	output:
		check = "checkpoints/{sample}/FUNANNOTATE_predict-direct.done",
		proteins = "results/{sample}/FUNANNOTATE-direct/{sample}_preds/predict_results/{sample}.gff3"
	params:
		folder = "{sample}",
		pred_folder = get_contig_prefix,
		sample_name = "{sample}",
		organism = config["predict"]["organism"],
		ploidy = config["predict"]["ploidy"],
		busco_db = config["funannotate_busco_set"],
		transcripts = get_transcripts_path,
		optional = config["predict"]["additional_params"],
		busco_seed_species = config["predict"]["busco_seed_species"],
		wd = os.getcwd()
	singularity:
		config["containers"]["funannotate"]
	log:
		"results/{sample}/logs/FUNANNOTATE_predict-direct.log"
	threads: config["predict"]["threads"] 
	shell:
		"""
		if [[ -d results/{params.folder}/FUNANNOTATE-direct ]]
		then
			rm -rf results/{params.folder}/FUNANNOTATE-direct
		fi
		mkdir results/{params.folder}/FUNANNOTATE-direct
		cd results/{params.folder}/FUNANNOTATE-direct
		export GENEMARK_PATH=/usr/local/Genemark
		export PATH=$PATH:/usr/local/SignalP

		## add some echos to know what is going on
		add_cmd=""
		if [[ -f "{params.transcripts[ests]}" ]]; then
			echo "Transcript evidence detected at {params.transcripts[ests]} - Will use in funannotate predict"
			add_cmd=$add_cmd" --transcript_evidence {params.transcripts[ests]}"
		else
			echo "No transcript evidence detected."
		fi
		if [[ "{params.optional}" != "None" ]]
		then
			add_cmd=$add_cmd" {params.optional}"
		fi

		funannotate predict -i {params.wd}/{input.assembly} -o {params.sample_name}_preds -s {params.sample_name} --name {params.pred_folder}_pred \
		--optimize_augustus --cpus {threads} --busco_db {params.busco_db} --organism {params.organism} --busco_seed_species {params.busco_seed_species} \
		--ploidy {params.ploidy} \
		--protein_evidence {params.wd}/data/funannotate_database/uniprot_sprot.fasta {params.wd}/results/{sample}/NR_PROTEIN_EVIDENCE/nr_external_proteins.cd-hit.fasta \
		--genemark_gtf {params.wd}/{input.gm_gtf} $add_cmd 2>&1 | tee {params.wd}/{log}

		##
		touch {params.wd}/{output.check}

		""" 

rule funannotate_predict_post_maker:
	input:
		assembly = rules.mask_repeats.output.soft,
		gm_gtf = rules.genemark.output.gtf,
		maker_pass2 = "checkpoints/{sample}/merge_MAKER_PASS2.ok"
	output:
		check = "checkpoints/{sample}/FUNANNOTATE_predict-post_maker.done",
		proteins = "results/{sample}/FUNANNOTATE-post_maker/{sample}_preds/predict_results/{sample}.gff3"
	params:
		folder = "{sample}",
		pred_folder = get_contig_prefix,
		sample_name = "{sample}",
		organism = config["predict"]["organism"],
		ploidy = config["predict"]["ploidy"],
		busco_db = config["funannotate_busco_set"],
		maker_weight= config["predict"]["maker_weight"],
		transcripts = get_transcripts_path,
		optional = config["predict"]["additional_params"],
		wd = os.getcwd()
	singularity:
		config["containers"]["funannotate"]
	log:
		"results/{sample}/logs/FUNANNOTATE_predict-post_maker.log"
	threads: config["predict"]["threads"] 
	shell:
		"""
		if [[ -d results/{params.folder}/FUNANNOTATE-post_maker ]]
		then
			rm -rf results/{params.folder}/FUNANNOTATE-post_maker
		fi
		mkdir results/{params.folder}/FUNANNOTATE-post_maker
		export GENEMARK_PATH=/usr/local/Genemark
		export PATH=$PATH:/usr/local/SignalP

		cd results/{params.folder}/FUNANNOTATE-post_maker

		if [ -d /data/database/trained_species/maker_{wildcards.sample} ]; then rm -rf /data/database/trained_species/maker_{wildcards.sample}; fi
		mkdir -p /data/database/trained_species/maker_{wildcards.sample}/augustus
		{params.wd}/bin/initiate_trained_species.sh maker {wildcards.sample} > /data/database/trained_species/maker_{wildcards.sample}/info.json

		#it's important that the directory has 'config' at it's base - funannotate expects that
		mkdir -p AUGUSTUS/config
		#copy from the original AUGUSTUS_CONFIG_PATH in the container
		cp -rf $AUGUSTUS_CONFIG_PATH/* AUGUSTUS/config/
		export AUGUSTUS_CONFIG_PATH=$(pwd)/AUGUSTUS/config/
		#these are the parameters after MAKER
		mkdir -p AUGUSTUS/config/species/maker_{wildcards.sample}
		cp {params.wd}/results/{params.folder}/AUGUSTUS.PASS2/training_params/* AUGUSTUS/config/species/maker_{wildcards.sample}/
		
		cd $AUGUSTUS_CONFIG_PATH/species/maker_{wildcards.sample}
		base=$(ls *_weightmatrix.txt | sed 's/_weightmatrix.txt//')
		echo -e "renaming all files"
		for f in $(ls -1 ); do mv $f $(echo $f | sed "s/^$base/maker_{params.folder}/"); done
		for f in $(ls -1 *parameters.cfg*); do echo -e "fixing $f - replacing '$base' with 'maker_{params.folder}'"; sed -i "s/$base/maker_{params.folder}/g" $f; done
		cd -
		cp -pv $AUGUSTUS_CONFIG_PATH/species/maker_{wildcards.sample}/* /data/database/trained_species/maker_{wildcards.sample}/augustus/

		## add some echos to know what is going on
		add_cmd=""
		echo "MAKER GFF detected at {params.wd}/results/{params.sample_name}/MAKER.PASS2/{params.sample_name}.all.maker.gff - Will use in funannotate predict"
		if [[ -f "{params.transcripts[ests]}" ]]; then
			echo "Transcript evidence detected at {params.transcripts[ests]} - Will use in funannotate predict"
			add_cmd=$add_cmd" --transcript_evidence {params.transcripts[ests]}"
		else
			echo "No transcript evidence detected."
		fi
		if [[ "{params.optional}" != "None" ]]
		then
			add_cmd=$add_cmd" {params.optional}"
		fi

		funannotate predict -i {params.wd}/{input.assembly} -o {params.sample_name}_preds -s {params.sample_name} --name {params.pred_folder}_pred \
		--optimize_augustus --cpus {threads} --busco_db {params.busco_db} --organism {params.organism} --busco_seed_species maker_{params.folder} \
		--ploidy {params.ploidy} \
		--other_gff {params.wd}/results/{params.sample_name}/MAKER.PASS2/{params.sample_name}.all.maker.gff:{params.maker_weight} \
		--protein_alignments {params.wd}/results/{params.sample_name}/FUNANNOTATE-direct/{params.sample_name}_preds/predict_misc/protein_alignments.gff3 \
		--genemark_gtf {params.wd}/{input.gm_gtf} $add_cmd 2>&1 | tee {params.wd}/{log}

		##
		touch {params.wd}/{output.check}

		""" 

rule funannotate_predict_post_braker:
	input:
		assembly = rules.mask_repeats.output.soft,
		gm_gtf = rules.genemark.output.gtf, # needs to choose as well. if braker protein get from braker, else get from genemark as usual
		braker = decide_funannotate_post_braker_input # this needs to become the gff file
	output:
		check = "checkpoints/{sample}/FUNANNOTATE_predict-post_braker.done",
		proteins = "results/{sample}/FUNANNOTATE-post_braker/{sample}_preds/predict_results/{sample}.gff3"
	params:
		folder = "{sample}",
		pred_folder = get_contig_prefix,
		sample_name = "{sample}",
		organism = config["predict"]["organism"],
		ploidy = config["predict"]["ploidy"],
		busco_db = config["funannotate_busco_set"],
		braker_weight= config["predict"]["braker_weight"],
		transcripts = get_transcripts_path,
		optional = config["predict"]["additional_params"],
		wd = os.getcwd()
	singularity:
		config["containers"]["funannotate"]
	log:
		"results/{sample}/logs/FUNANNOTATE_predict-post_braker.log"
	threads: config["predict"]["threads"] 
	shell:
		"""
		if [[ -d results/{params.folder}/FUNANNOTATE-post_braker ]]
		then
			rm -rf results/{params.folder}/FUNANNOTATE-post_braker
		fi
		mkdir results/{params.folder}/FUNANNOTATE-post_braker
		export GENEMARK_PATH=/usr/local/Genemark
		export PATH=$PATH:/usr/local/SignalP

		cd results/{params.folder}/FUNANNOTATE-post_braker

		if [ -d /data/database/trained_species/braker_{wildcards.sample} ]; then rm -rf /data/database/trained_species/braker_{wildcards.sample}; fi
		mkdir -p /data/database/trained_species/braker_{wildcards.sample}/augustus
		{params.wd}/bin/initiate_trained_species.sh braker {wildcards.sample} > /data/database/trained_species/braker_{wildcards.sample}/info.json

		#it's important that the directory has 'config' at it's base - funannotate expects that
		mkdir -p AUGUSTUS/config
		#copy from the original AUGUSTUS_CONFIG_PATH in the container
		cp -rf $AUGUSTUS_CONFIG_PATH/* AUGUSTUS/config/
		export AUGUSTUS_CONFIG_PATH=$(pwd)/AUGUSTUS/config/
		# this is specific to braker
		tar xfz {params.wd}/{input.braker[1]} -C $AUGUSTUS_CONFIG_PATH/
		cd $AUGUSTUS_CONFIG_PATH/species/{wildcards.sample}
		echo -e "renaming all files"
		for f in $(ls -1 {wildcards.sample}_*); do mv $f $(echo $f | sed "s/^{wildcards.sample}/braker_{wildcards.sample}/"); done
		for f in $(ls -1 *parameters.cfg*); do echo -e "fixing $f - replacing '{wildcards.sample}' with 'braker_{wildcards.sample}'"; sed -i "s/{wildcards.sample}/braker_{wildcards.sample}/g" $f; done
		cd -
		mv $AUGUSTUS_CONFIG_PATH/species/{wildcards.sample} $AUGUSTUS_CONFIG_PATH/species/braker_{wildcards.sample}
		cp -pv $AUGUSTUS_CONFIG_PATH/species/braker_{wildcards.sample}/* /data/database/trained_species/braker_{wildcards.sample}/augustus/

		## add some echos to know what is going on
		add_cmd=""
		echo "BRAKER GFF detected at {params.wd}/{input.braker[0]} - Will use in funannotate predict"
		if [[ -f "{params.transcripts[ests]}" ]]; then
			echo "Transcript evidence detected at {params.transcripts[ests]} - Will use in funannotate predict"
			add_cmd=$add_cmd" --transcript_evidence {params.transcripts[ests]}"
		else
			echo "No transcript evidence detected."
		fi
		if [[ "{params.optional}" != "None" ]]
		then
			add_cmd=$add_cmd" {params.optional}"
		fi

		funannotate predict -i {params.wd}/{input.assembly} -o {params.sample_name}_preds -s {params.sample_name} --name {params.pred_folder}_pred \
		--optimize_augustus --cpus {threads} --busco_db {params.busco_db} --organism {params.organism} --busco_seed_species braker_{params.folder} \
		--ploidy {params.ploidy} \
		--protein_alignments {params.wd}/results/{params.sample_name}/FUNANNOTATE-direct/{params.sample_name}_preds/predict_misc/protein_alignments.gff3 \
		--other_gff {params.wd}/{input.braker[0]}:{params.braker_weight} \
		--genemark_gtf {params.wd}/{input.gm_gtf} $add_cmd 2>&1 | tee {params.wd}/{log}

		##
		touch {params.wd}/{output.check}

		""" 
rule funannotate_predict_post_all:
	input:
		assembly = rules.mask_repeats.output.soft,
		gm_gtf = rules.genemark.output.gtf, # needs to choose as well. if braker protein get from braker, else get from genemark as usual
		braker = decide_funannotate_post_braker_input, # this needs to become the gff file
		maker = "checkpoints/{sample}/merge_MAKER_PASS2.ok"
	output:
		check = "checkpoints/{sample}/FUNANNOTATE_predict-post_all.done",
		proteins = "results/{sample}/FUNANNOTATE-post_all/{sample}_preds/predict_results/{sample}.gff3"
	params:
		folder = "{sample}",
		pred_folder = get_contig_prefix,
		sample_name = "{sample}",
		organism = config["predict"]["organism"],
		ploidy = config["predict"]["ploidy"],
		busco_db = config["funannotate_busco_set"],
		maker_weight= config["predict"]["maker_weight"],
		braker_weight= config["predict"]["braker_weight"],
		transcripts = get_transcripts_path,
		optional = config["predict"]["additional_params"],
		wd = os.getcwd()
	singularity:
		config["containers"]["funannotate"]
	log:
		"results/{sample}/logs/FUNANNOTATE_predict-post_all.log"
	threads: config["predict"]["threads"] 
	shell:
		"""
		if [[ -d results/{params.folder}/FUNANNOTATE-post_all ]]
		then
			rm -rf results/{params.folder}/FUNANNOTATE-post_all
		fi
		mkdir results/{params.folder}/FUNANNOTATE-post_all
		export GENEMARK_PATH=/usr/local/Genemark
		export PATH=$PATH:/usr/local/SignalP

		cd results/{params.folder}/FUNANNOTATE-post_all

		if [ -d /data/database/trained_species/all_braker_{wildcards.sample} ]; then rm -rf /data/database/trained_species/all_braker_{wildcards.sample}; fi
		mkdir -p /data/database/trained_species/all_braker_{wildcards.sample}/augustus
		{params.wd}/bin/initiate_trained_species.sh braker {wildcards.sample} > /data/database/trained_species/all_braker_{wildcards.sample}/info.json

		#it's important that the directory has 'config' at it's base - funannotate expects that
		mkdir -p AUGUSTUS/config
		#copy from the original AUGUSTUS_CONFIG_PATH in the container
		cp -rf $AUGUSTUS_CONFIG_PATH/* AUGUSTUS/config/
		export AUGUSTUS_CONFIG_PATH=$(pwd)/AUGUSTUS/config/
		# this is specific to braker
		tar xfz {params.wd}/{input.braker[1]} -C $AUGUSTUS_CONFIG_PATH/
		cd $AUGUSTUS_CONFIG_PATH/species/{wildcards.sample}
		echo -e "renaming all files"
		for f in $(ls -1 {wildcards.sample}_*); do mv $f $(echo $f | sed "s/^{wildcards.sample}/all_braker_{wildcards.sample}/"); done
		for f in $(ls -1 *parameters.cfg*); do echo -e "fixing $f - replacing '{wildcards.sample}' with 'all_braker_{wildcards.sample}'"; sed -i "s/{wildcards.sample}/all_braker_{wildcards.sample}/g" $f; done
		cd -
		mv $AUGUSTUS_CONFIG_PATH/species/{wildcards.sample} $AUGUSTUS_CONFIG_PATH/species/all_braker_{wildcards.sample}
		cp -pv $AUGUSTUS_CONFIG_PATH/species/all_braker_{wildcards.sample}/* /data/database/trained_species/all_braker_{wildcards.sample}/augustus/

		## add some echos to know what is going on
		add_cmd=""
		echo "BRAKER GFF detected at {params.wd}/{input.braker[0]} - Will use in funannotate predict"
		echo "MAKER GFF detected at {params.wd}/results/{params.sample_name}/MAKER.PASS2/{params.sample_name}.all.maker.gff - Will use in funannotate predict"
		if [[ -f "{params.transcripts[ests]}" ]]; then
			echo "Transcript evidence detected at {params.transcripts[ests]} - Will use in funannotate predict"
			add_cmd=$add_cmd" --transcript_evidence {params.transcripts[ests]}"
		else
			echo "No transcript evidence detected."
		fi
		if [[ "{params.optional}" != "None" ]]
		then
			add_cmd=$add_cmd" {params.optional}"
		fi

		funannotate predict -i {params.wd}/{input.assembly} -o {params.sample_name}_preds -s {params.sample_name} --name {params.pred_folder}_pred \
		--optimize_augustus --cpus {threads} --busco_db {params.busco_db} --organism {params.organism} --busco_seed_species all_braker_{params.folder} \
		--ploidy {params.ploidy} \
		--protein_evidence {params.wd}/data/funannotate_database/uniprot_sprot.fasta {params.wd}/results/{sample}/NR_PROTEIN_EVIDENCE/nr_external_proteins.cd-hit.fasta \
		--other_gff {params.wd}/{input.braker[0]}:{params.braker_weight} {params.wd}/results/{params.sample_name}/MAKER.PASS2/{params.sample_name}.all.maker.gff:{params.maker_weight} \
		--genemark_gtf {params.wd}/{input.gm_gtf} $add_cmd 2>&1 | tee {params.wd}/{log}

		##
		touch {params.wd}/{output.check}

		""" 

rule tarpredict_direct:
	input:
		{rules.funannotate_predict_direct.output}
	output:
		"checkpoints/{sample}/FUNANNOTATE_tarpredict-direct.done"
	params:
		pred_folder = get_contig_prefix,
		folder = "{sample}"
	shell:
		"""
		cd results/{params.folder}/FUNANNOTATE-direct/{params.folder}_preds/predict_misc
		echo -e "Archiving $(pwd)/EVM -> $(pwd)/EVM.tar"
		tar -cf EVM.tar EVM && rm -r EVM
		echo -e "Archiving $(pwd)/busco -> $(pwd)/busco.tar"
		tar -cf busco.tar busco && rm -r busco
		echo -e "Archiving $(pwd)/busco_proteins -> $(pwd)/busco_proteins.tar"
		tar -cf busco_proteins.tar busco_proteins && rm -r busco_proteins
		touch ../../../../../{output}
		"""		

rule tarpredict_post_maker:
	input:
		{rules.funannotate_predict_post_maker.output}
	output:
		"checkpoints/{sample}/FUNANNOTATE_tarpredict-post_maker.done"
	params:
		pred_folder = get_contig_prefix,
		folder = "{sample}"
	shell:
		"""
		cd results/{params.folder}/FUNANNOTATE-post_maker/{params.folder}_preds/predict_misc
		echo -e "Archiving $(pwd)/EVM -> $(pwd)/EVM.tar"
		tar -cf EVM.tar EVM && rm -r EVM
		echo -e "Archiving $(pwd)/busco -> $(pwd)/busco.tar"
		tar -cf busco.tar busco && rm -r busco
		echo -e "Archiving $(pwd)/busco_proteins -> $(pwd)/busco_proteins.tar"
		tar -cf busco_proteins.tar busco_proteins && rm -r busco_proteins
		touch ../../../../../{output}
		"""		

rule tarpredict_post_braker:
	input:
		{rules.funannotate_predict_post_braker.output}
	output:
		"checkpoints/{sample}/FUNANNOTATE_tarpredict-post_braker.done"
	params:
		pred_folder = get_contig_prefix,
		folder = "{sample}"
	shell:
		"""
		cd results/{params.folder}/FUNANNOTATE-post_braker/{params.folder}_preds/predict_misc
		echo -e "Archiving $(pwd)/EVM -> $(pwd)/EVM.tar"
		tar -cf EVM.tar EVM && rm -r EVM
		echo -e "Archiving $(pwd)/busco -> $(pwd)/busco.tar"
		tar -cf busco.tar busco && rm -r busco
		echo -e "Archiving $(pwd)/busco_proteins -> $(pwd)/busco_proteins.tar"
		tar -cf busco_proteins.tar busco_proteins && rm -r busco_proteins
		touch ../../../../../{output}
		"""		
rule tarpredict_post_all:
	input:
		{rules.funannotate_predict_post_all.output}
	output:
		"checkpoints/{sample}/FUNANNOTATE_tarpredict-post_all.done"
	params:
		pred_folder = get_contig_prefix,
		folder = "{sample}"
	shell:
		"""
		cd results/{params.folder}/FUNANNOTATE-post_all/{params.folder}_preds/predict_misc
		echo -e "Archiving $(pwd)/EVM -> $(pwd)/EVM.tar"
		tar -cf EVM.tar EVM && rm -r EVM
		echo -e "Archiving $(pwd)/busco -> $(pwd)/busco.tar"
		tar -cf busco.tar busco && rm -r busco
		echo -e "Archiving $(pwd)/busco_proteins -> $(pwd)/busco_proteins.tar"
		tar -cf busco_proteins.tar busco_proteins && rm -r busco_proteins
		touch ../../../../../{output}
		"""		
#rule aggregate_funannotate_predict:
#	input:
#		expand("checkpoints/{name}/FUNANNOTATE_tarpredict.done", name=get_sample_selection())
#	output:
#		"checkpoints/{sample}/aggregate_funannotate_predict.done"
#	shell:
#		"""
#		touch {output}
#		"""	
