			
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

		echo "{params.transcripts[ests]}"
		if [[ -f "{params.transcripts[ests]}" ]]; then
			echo "Transcript evidence detected. Will use in funannotate predict"
		else
			echo "No transcript evidence detected."
		fi

		funannotate predict -i {params.wd}/{input.assembly} -o {params.sample_name}_preds -s {params.sample_name} --name {params.pred_folder}_pred \
		--optimize_augustus --cpus {threads} --busco_db {params.busco_db} --organism {params.organism} --busco_seed_species {params.busco_seed_species} \
		--ploidy {params.ploidy} \
		--protein_evidence {params.wd}/data/funannotate_database/uniprot_sprot.fasta {params.wd}/results/{sample}/NR_PROTEIN_EVIDENCE/nr_external_proteins.cd-hit.fasta \
		--genemark_gtf {params.wd}/{input.gm_gtf} \
		$(if [[ -f "{params.transcripts[ests]}" ]]; then echo -e "--transcript_evidence {params.transcripts[ests]}"; fi) \
		$(if [[ "{params.optional}" != "None" ]]; then echo -n "{params.optional}"; fi) 2>&1 | tee {params.wd}/{log}

		# this is just temporal
		#cd -
		#mv /tmp/annocomba/results/{params.folder}/FUNANNOTATE .
		#rm -rf /tmp/annocomba
		##
		touch {params.wd}/{output.check}

		""" 

rule funannotate_predict_post_maker:
	input:
		assembly = rules.mask_repeats.output.soft,
		gm_gtf = rules.genemark.output.gtf,
		maker_pass2="checkpoints/{sample}/merge_MAKER_PASS2.ok"
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

		if [[ -f checkpoints/{params.sample_name}/merge_MAKER_PASS2.ok ]]; then # this case assumes maker was run before in which case some parameters will be recycled.
			if [ -d /data/database/trained_species/maker_{params.folder} ]; then rm -rf /data/database/trained_species/maker_{params.folder}; fi
			mkdir -p /data/database/trained_species/maker_{params.folder}/augustus

			#these are the parameters after MAKER
			cp results/{params.folder}/AUGUSTUS.PASS2/training_params/* /data/database/trained_species/maker_{params.folder}/augustus/

			cd /data/database/trained_species/maker_{params.folder}
			#get a json file as template from some random species. Wouldn't have to be Schistosoma
			cp ../schistosoma/info.json .
			sed -i "s/schistosoma/maker_{params.folder}/" info.json
			cd -
			cd /data/database/trained_species/maker_{params.folder}/augustus

			base=$(ls *_weightmatrix.txt | sed 's/_weightmatrix.txt//')
			echo -e "renaming all files"
			for f in $(ls -1 ); do mv $f $(echo $f | sed "s/^$base/maker_{params.folder}/"); done
			for f in $(ls -1 *parameters.cfg*); do echo -e "fixing $f - replacing '$base' with 'maker_{params.folder}'"; sed -i "s/$base/maker_{params.folder}/g" $f; done
			cd -
			cd results/{params.folder}/FUNANNOTATE-post_maker


			#it's important that the directory has 'config' at it's base - funannotate expects that
			mkdir -p AUGUSTUS/config
			#copy from the original AUGUSTUS_CONFIG_PATH in the container
			cp -rf $AUGUSTUS_CONFIG_PATH/* AUGUSTUS/config/
			#specify new AUGUSTUS_CONFIG
			#export PATH=/usr/share/augustus/scripts:$PATH
			export AUGUSTUS_CONFIG_PATH=$(pwd)/AUGUSTUS/config/
			mkdir $AUGUSTUS_CONFIG_PATH/species/maker_{params.folder}
			cp -p /data/database/trained_species/maker_{params.folder}/augustus/* $AUGUSTUS_CONFIG_PATH/species/maker_{params.folder}/
		fi

		## add some echos to know what is going on
		echo "{params.wd}/results/{params.sample_name}/MAKER.PASS2/{params.sample_name}.all.maker.proteins.fasta"
		if [[ -f {params.wd}/results/{params.sample_name}/MAKER.PASS2/{params.sample_name}.all.maker.proteins.fasta ]]; then
			echo "MAKER.PASS2 proteins detected. Will use in funannotate predict:"
		fi
		echo "{params.wd}/results/{params.sample_name}/MAKER.PASS2/{params.sample_name}.all.maker.gff"
		if [[ -f {params.wd}/results/{params.sample_name}/MAKER.PASS2/{params.sample_name}.all.maker.gff ]]; then
			echo "MAKER.PASS2 GFF detected. Will use in funannotate predict"
		fi
		echo "{params.transcripts[ests]}"
		if [[ -f "{params.transcripts[ests]}" ]]; then
			echo "Transcript evidence detected. Will use in funannotate predict"
		else
			echo "No transcript evidence detected."
		fi

		funannotate predict -i {params.wd}/{input.assembly} -o {params.sample_name}_preds -s {params.sample_name} --name {params.pred_folder}_pred \
		--optimize_augustus --cpus {threads} --busco_db {params.busco_db} --organism {params.organism} --busco_seed_species maker_{params.folder} \
		--ploidy {params.ploidy} \
		--protein_evidence {params.wd}/data/funannotate_database/uniprot_sprot.fasta results/{sample}/NR_PROTEIN_EVIDENCE/nr_external_proteins.cd-hit.fasta \
		--other_gff {params.wd}/results/{params.sample_name}/MAKER.PASS2/{params.sample_name}.all.maker.gff:{params.maker_weight} \
		--genemark_gtf {params.wd}/{input.gm_gtf} \
		$(if [[ -f "{params.transcripts[ests]}" ]]; then echo -e "--transcript_evidence {params.transcripts[ests]}"; fi) \
		$(if [[ "{params.optional}" != "None" ]]; then echo -n "{params.optional}"; fi) 2>&1 | tee {params.wd}/{log}

		# this is just temporal
		#cd -
		#mv /tmp/annocomba/results/{params.folder}/FUNANNOTATE .
		#rm -rf /tmp/annocomba
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
#rule aggregate_funannotate_predict:
#	input:
#		expand("checkpoints/{name}/FUNANNOTATE_tarpredict.done", name=get_sample_selection())
#	output:
#		"checkpoints/{sample}/aggregate_funannotate_predict.done"
#	shell:
#		"""
#		touch {output}
#		"""	
