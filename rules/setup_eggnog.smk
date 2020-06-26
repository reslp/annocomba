rule setup_eggnog:
	output:	
		"data/eggnogdb_database/.setup.done"
	params:
		database = config["eggnog_database"]
	singularity:
		config["containers"]["eggnog_mapper"]
	shell:
		"""
		download_eggnog_data.py {params.database} -y --data_dir data/eggnogdb_database/
		touch {output}
		"""
