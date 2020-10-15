rule annotate:
	input:
		rules.iprscan.output,
		rules.remote.output,
		rules.eggnog.output
	output:
		"checkpoints/{sample}/FUNANNOTATE_annotate.{contig_prefix}.done"
	params:
		folder="{sample}",
		pred_folder="{contig_prefix}",
		buscodb=config["busco_set"]
	log:
		"results/{sample}/logs/FUNANNOTATE_annotate.{contig_prefix}.log"
	singularity:
		config["containers"]["funannotate"]
	threads: config["annotate"]["threads"]
	shell:
		"""
		cd results/{params.folder}/FUNANNOTATE
		funannotate annotate -i {params.pred_folder}_preds --sbt ../../../data/genbank_template.txt --eggnog {params.pred_folder}_preds/eggnog_results.emapper.annotations --busco_db {params.buscodb} --cpus {threads} >& ../../../{log}
		#funannotate annotate -i {params.pred_folder}_preds --sbt ../../data/genbank_template.txt --cpus {threads} >& ../../{log}
		touch ../../../{output}
		"""

species_names, preddirs = glob_wildcards("results/{sample}/FUNANNOTATE/{preddir}_preds")
# funannotate compare does not allow / charcters in the output folder
# therefore the folder has to be moved manually to the results folder.
if config["compare"]["phylogeny"] == "yes" or config["compare"]["histograms"] == "yes":
	rule compare:
		input:
#			checkpoint=expand("checkpoints/{sam}/FUNANNOTATE_annotate.{preddir}.done", zip, sam=sample_data.index.tolist(), preddir=preddirs),
#			checkpoint = expand("checkpoints/{species_name}/FUNANNOTATE_annotate.{preddir}.done", zip, species_name=species_names, preddir=preddirs),
			checkpoint = expand("checkpoints/{name.sample}/FUNANNOTATE_annotate.{name.contig_prefix}.done", name=sample_prefix_units.itertuples()),
		output:
			checkpoint = "checkpoints/FUNANNOTATE_compare.done"
		params:
#			folders = expand("results/{species_name}/FUNANNOTATE/{preddir}_preds", zip, species_name=species_names, preddir=preddirs),
			folders = expand("results/{name.sample}/FUNANNOTATE/{name.contig_prefix}_preds", name=sample_prefix_units.itertuples()),
			num_orthos = config["compare"]["num_orthos"],
			ml_method = config["compare"]["ml_method"]
		singularity:
			config["containers"]["funannotate"]
		log:
			"results/FUNANNOTATE_compare.log"
		threads: config["compare"]["threads"]
		shell:
			"""
			if [ $(echo "{input.checkpoint}" | wc -w) -gt 1 ]; then
				funannotate compare --cpus {threads} --num_orthos {params.num_orthos} --ml_method {params.ml_method} -i {params.folders} >& {log}
				cp -r funannotate_compare results/
				cp funannotate_compare.tar.gz results/
				mv results/funannotate_compare results/FUNANNOTATE_COMPARE
				rm -rf funannotate_compare
				rm funannotate_compare.tar.gz
				touch {output.checkpoint}
			else
				echo "Not enough species to run funannotate compare" >& {log}
				touch {output.checkpoint}
			fi
			"""	
else:
	rule compare:
		input:
#			checkpoint=expand("checkpoints/{sam}/FUNANNOTATE_annotate.{preddir}.done", zip, sam=sample_data.index.tolist(), preddir=preddirs),
			checkpoint = expand("checkpoints/{name.sample}/FUNANNOTATE_annotate.{name.contig_prefix}.done", name=sample_prefix_units.itertuples()),
		output:
			checkpoint = "checkpoints/FUNANNOTATE_compare.done"
		params:
#			folders = expand("results/{species_name}/FUNANNOTATE/{preddir}_preds", zip, species_name=species_names, preddir=preddirs),
			folders = expand("results/{name.sample}/FUNANNOTATE/{name.contig_prefix}_preds", name=sample_prefix_units.itertuples()),
			num_orthos = config["compare"]["num_orthos"],
			ml_method = config["compare"]["ml_method"]
		singularity:
			"docker://reslp/funannotate:experimental"
		log:
			"results/FUNANNOTATE_compare.log"
		threads: config["compare"]["threads"]
		shell:
			"""
			if [ $(echo "{input.checkpoint}" | wc -w) -gt 1 ]; then
				funannotate compare --cpus {threads} --num_orthos {params.num_orthos} --ml_method {params.ml_method} -i {params.folders} >& {log}
				cp -r funannotate_compare results/
				cp funannotate_compare.tar.gz results/
				mv results/funannotate_compare results/FUNANNOTATE_COMPARE
				rm -rf funannotate_compare
				rm funannotate_compare.tar.gz
				touch {output.checkpoint}
			else
				echo "Not enough species to run funannotate compare" >& {log}
				touch {output.checkpoint}
			fi
			"""
