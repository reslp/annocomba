rule setup_funannotate:
	output:	
		"data/funannotate_database/.setup.done"
	params:
		databases = config["funannotate_databases"]
	singularity:
		config["containers"]["funannotate_setup"]
	shell:
		"""
		funannotate setup -i {params.databases}
		funannotate database
		touch {output}
		"""
