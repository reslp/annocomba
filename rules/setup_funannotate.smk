rule setup_funannotate:
	output:	
		"data/funannotate_database/.setup.done"
	params:
		databases = config["funannotate_databases"],
		busco_set = config["busco_set"]
	singularity:
		config["containers"]["funannotate_setup"]
	shell:
		"""
		funannotate setup -i {params.databases} --busco_db {params.busco_set}
		funannotate database
		touch {output}
		"""
