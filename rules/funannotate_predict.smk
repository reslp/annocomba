rule predict:
	input:
		assembly = rules.repeatmasker.output.masked,
		maker_proteins = rules.merge_MAKER_PASS2.output.proteins,
		maker_gff = rules.merge_MAKER_PASS2.output.all_gff,
		genemark_ok = rules.genemark.output.ok
	output:
		"results/{sample}/checkpoints/{sample}_FUNANNOTATE_predict.done"
	params:
		folder = "{sample}",
		pred_folder = get_contig_prefix,
		sample_name = "{sample}",
		organism = config["predict"]["organism"],
		busco_seed_species = config["predict"]["busco_seed_species"],
		ploidy = config["predict"]["ploidy"],
		busco_db = config["predict"]["busco_db"],
		wd = os.getcwd()
	singularity:
		config["containers"]["funannotate"]
	log:
		"logs/FUNANNOTATE_{sample}_predict.log"
	threads: config["predict"]["threads"] 
	shell:
		"""
		if [[ ! -d results/{params.folder}/FUNANNOTATE ]]
		then
			mkdir results/{params.folder}/FUNANNOTATE
		fi
		cd results/{params.folder}/FUNANNOTATE
		funannotate predict -i ../../../{input.assembly} -o {params.pred_folder}_preds -s {params.sample_name} --name {params.pred_folder}_pred --optimize_augustus --cpus {threads} --busco_db {params.busco_db} --organism {params.organism} --busco_seed_species {params.busco_seed_species} --ploidy {params.ploidy} --protein_evidence {params.wd}/{input.maker_proteins} {params.wd}/data/funannotate_database/uniprot_sprot.fasta --other_gff {params.wd}/{input.maker_gff}:1 --genemark_gtf {params.wd}/results/{params.sample_name}/GENEMARK/genemark.gtf >& ../{log}
		touch ../../../{output}
		""" 

rule tarpredict:
	input:
		{rules.predict.output}
	output:
		"results/{sample}/checkpoints/{sample}_FUNANNOTATE_tarpredict.done"
	params:
		pred_folder = get_contig_prefix,
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
