rule setup_eggnog:
	output:	
		"data/eggnog_database/.setup.done"
	params:
		database = config["eggnog_database"],
		location = os.environ["EGGNOGDB"] 
	singularity:
		config["containers"]["eggnog_mapper"]
	shell:
		"""
		download_eggnog_data.py {params.database} -y --data_dir {params.location}/
		touch {output}
		"""
