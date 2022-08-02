if (os.environ["RUNMODE"]) == "maker":
	rule predict:
		input:
			assembly = rules.mask_repeats.output.soft,
			maker_proteins = rules.merge_MAKER_PASS2.output.proteins,
			maker_gff = rules.merge_MAKER_PASS2.output.all_gff
		output:
			check = "checkpoints/{sample}/FUNANNOTATE_predict.{contig_prefix}.done",
			proteins = "results/{sample}/FUNANNOTATE/{contig_prefix}_preds/predict_results/{sample}.proteins.fa",
			gff = "results/{sample}/FUNANNOTATE/{contig_prefix}_preds/predict_results/{sample}.gff3",
			assembly = "results/{sample}/FUNANNOTATE/{contig_prefix}_preds/predict_results/{sample}.scaffolds.fa",
			tbl = "results/{sample}/FUNANNOTATE/{contig_prefix}_preds/predict_results/{sample}.tbl",
			gbk = "results/{sample}/FUNANNOTATE/{contig_prefix}_preds/predict_results/{sample}.gbk"
		log:
			"results/{sample}/logs/FUNANNOTATE_predict.{contig_prefix}.log"
		params:
			sample = "{sample}",
			contig_prefix = "{contig_prefix}",
			wd = os.getcwd()
		singularity: 
			config["containers"]["funannotate"]
		shell:
			"""
				echo "FUNANNOTATE predict will not be run (runmode maker was specified). Still some of the files need to be present for the subsquent functional annotation steps to work."
				cp {input.assembly} {output.assembly} 
				cp {input.maker_proteins} {output.proteins}
				
				bin/makergff_to_funannotategff.py -gff {input.maker_gff} > {output.gff} 
				SP=$(echo {params.sample} | sed 's/_/ /')
				funannotate util gff2tbl -g {output.gff} -f {output.assembly} > {output.tbl}
				
				# alternative would be to make this shadow and move files to the correct place.
				cd results/{params.sample}/FUNANNOTATE/{params.contig_prefix}_preds/predict_results/
				funannotate util tbl2gbk -i {params.wd}/{output.tbl} -f {params.wd}/{output.assembly} -s "$SP"
				
				cd {params.wd}
				touch {output.check}
			"""
	rule tarpredict:
                input:
                        {rules.predict.output}
                output:
                        "checkpoints/{sample}/FUNANNOTATE_tarpredict.{contig_prefix}.done"
		shell:
			"""
			touch {output}
			"""
else:
	rule predict:
		input:
			assembly = rules.mask_repeats.output.soft,
			maker_proteins = rules.merge_MAKER_PASS2.output.proteins,
			maker_gff = rules.merge_MAKER_PASS2.output.all_gff,
			genemark_ok = rules.genemark.output.check
		output:
			check = "checkpoints/{sample}/FUNANNOTATE_predict.{contig_prefix}.done",
			proteins = "results/{sample}/FUNANNOTATE/{contig_prefix}_preds/predict_results/{sample}.proteins.fa"
		params:
			folder = "{sample}",
			pred_folder = "{contig_prefix}",
			sample_name = "{sample}",
			organism = config["predict"]["organism"],
			busco_seed_species = config["busco_species"],
			ploidy = config["predict"]["ploidy"],
			busco_db = config["busco_set"],
			maker_weight= config["predict"]["maker_weight"],
			transcripts = get_transcripts_path,
			optional = config["predict"]["additional_params"],
			wd = os.getcwd()
		singularity:
			config["containers"]["funannotate"]
		log:
			"results/{sample}/logs/FUNANNOTATE_predict.{contig_prefix}.log"
		threads: config["predict"]["threads"] 
		shell:
			"""
			if [[ -d results/{params.folder}/FUNANNOTATE ]]
			then
				rm -rf results/{params.folder}/FUNANNOTATE
			fi
			mkdir results/{params.folder}/FUNANNOTATE
			export GENEMARK_PATH=/usr/local/Genemark
			export PATH=$PATH:/usr/local/SignalP

			if [ -d /data/database/trained_species/maker{params.folder} ]; then rm -rf /data/database/trained_species/maker{params.folder}; fi
			mkdir -p /data/database/trained_species/maker{params.folder}/augustus

			#these are the parameters after MAKER
			cp results/{params.folder}/AUGUSTUS.PASS2/training_params/* /data/database/trained_species/maker{params.folder}/augustus/

			cd /data/database/trained_species/maker{params.folder}
			#get a json file as template from some random species. Wouldn't have to be Schistosoma
			cp ../schistosoma/info.json .
			sed -i "s/schistosoma/maker{params.folder}/" info.json
			cd -
			cd /data/database/trained_species/maker{params.folder}/augustus

			base=$(ls *_weightmatrix.txt | sed 's/_weightmatrix.txt//')
			echo -e "renaming all files"
			for f in $(ls -1 ); do mv $f $(echo $f | sed "s/^$base/maker{params.folder}/"); done
			for f in $(ls -1 *parameters.cfg*); do echo -e "fixing $f - replacing '$base' with 'maker{params.folder}'"; sed -i "s/$base/maker{params.folder}/g" $f; done
			cd -

			cd results/{params.folder}/FUNANNOTATE

			# this is just temporal
			#cd ..
			#rm -rf FUNANNOTATE
			#mkdir -p /tmp/annocomba/results/{params.folder}
			#ln -s {params.wd}/results/{params.folder}/* /tmp/annocomba/results/{params.folder}/
			#mkdir /tmp/annocomba/results/{params.folder}/FUNANNOTATE
			#cd /tmp/annocomba/results/{params.folder}/FUNANNOTATE
			##

			#it's important that the directory has 'config' at it's base - funannotate expects that
			mkdir -p AUGUSTUS/config
			#copy from the original AUGUSTUS_CONFIG_PATH in the container
			cp -rf $AUGUSTUS_CONFIG_PATH/* AUGUSTUS/config/
			#specify new AUGUSTUS_CONFIG
			export AUGUSTUS_CONFIG_PATH=$(pwd)/AUGUSTUS/config/
			mkdir $AUGUSTUS_CONFIG_PATH/species/maker{params.folder}
			cp -p /data/database/trained_species/maker{params.folder}/augustus/* $AUGUSTUS_CONFIG_PATH/species/maker{params.folder}/

			funannotate predict -i ../../../{input.assembly} -o {params.pred_folder}_preds -s {params.sample_name} --name {params.pred_folder}_pred \
			--optimize_augustus --cpus {threads} --busco_db {params.busco_db} --organism {params.organism} --busco_seed_species maker{params.folder} \
			--ploidy {params.ploidy} --protein_evidence {params.wd}/{input.maker_proteins} {params.wd}/data/funannotate_database/uniprot_sprot.fasta \
			--other_gff {params.wd}/{input.maker_gff}:{params.maker_weight} \
			--genemark_gtf {params.wd}/results/{params.sample_name}/GENEMARK/genemark.gtf \
			$(if [[ -f "{params.transcripts[ests]}" ]]; then echo -e "--transcript_evidence {params.transcripts[ests]}"; fi) \
			$(if [[ "{params.optional}" != "None" ]]; then echo -n "{params.optional}"; fi) >& {params.wd}/{log}

			# this is just temporal
			#cd -
			#mv /tmp/annocomba/results/{params.folder}/FUNANNOTATE .
			#rm -rf /tmp/annocomba
			##
			touch {params.wd}/{output.check}
	
			""" 

	rule tarpredict:
		input:
			{rules.predict.output}
		output:
			"checkpoints/{sample}/FUNANNOTATE_tarpredict.{contig_prefix}.done"
		params:
			pred_folder = "{contig_prefix}",
			folder = "{sample}"
		shell:
			"""
			cd results/{params.folder}/FUNANNOTATE/{params.pred_folder}_preds/predict_misc
			echo -e "Archiving $(pwd)/EVM -> $(pwd)/EVM.tar"
			tar -cf EVM.tar EVM && rm -r EVM
			echo -e "Archiving $(pwd)/busco -> $(pwd)/busco.tar"
			tar -cf busco.tar busco && rm -r busco
			echo -e "Archiving $(pwd)/busco_proteins -> $(pwd)/busco_proteins.tar"
			tar -cf busco_proteins.tar busco_proteins && rm -r busco_proteins
			touch ../../../../../{output}
			"""		
