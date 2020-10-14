rule predict:
	input:
		assembly = rules.mask_repeats.output.soft,
		maker_proteins = rules.merge_MAKER_PASS2.output.proteins,
		maker_gff = rules.merge_MAKER_PASS2.output.all_gff,
		genemark_ok = rules.genemark.output.ok
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
		wd = os.getcwd()
	singularity:
		config["containers"]["funannotate"]
	log:
		"results/{sample}/logs/FUNANNOTATE_predict.{contig_prefix}.log"
	threads: config["predict"]["threads"] 
	shell:
		"""
		if [[ ! -d results/{params.folder}/FUNANNOTATE ]]
		then
			mkdir results/{params.folder}/FUNANNOTATE
		fi
		cd results/{params.folder}/FUNANNOTATE
		funannotate predict -i ../../../{input.assembly} -o {params.pred_folder}_preds -s {params.sample_name} --name {params.pred_folder}_pred --optimize_augustus --cpus {threads} --busco_db {params.busco_db} --organism {params.organism} --busco_seed_species {params.busco_seed_species} --ploidy {params.ploidy} --protein_evidence {params.wd}/{input.maker_proteins} {params.wd}/data/funannotate_database/uniprot_sprot.fasta --other_gff {params.wd}/{input.maker_gff}:{params.maker_weight} --genemark_gtf {params.wd}/results/{params.sample_name}/GENEMARK/genemark.gtf >& {params.wd}/{log}
		
		cd {params.pred_folder}_preds/predict_misc	
		
		tar -cvf EVM_busco.tar EVM_busco && rm -r EVM_busco
                tar -cvf busco.tar busco && rm -r busco
                tar -cvf genemark.tar genemark && rm -r genemark
                tar -cvf busco_proteins.tar busco_proteins && rm -r busco_proteins
                tar -cvf EVM.tar EVM && rm -r EVM

		touch ../../../../../{output.check}

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
		tar -cvf EVM_busco.tar EVM_busco && rm -r EVM_busco
		tar -cvf busco.tar busco && rm -r busco
		tar -cvf genemark.tar genemark && rm -r genemark
		tar -cvf busco_proteins.tar busco_proteins && rm -r busco_proteins
		tar -cvf EVM.tar EVM && rm -r EVM
		touch ../../../../../{output}
		"""		
