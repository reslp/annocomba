import os

rule setup_eggnog:
	output:	
		"data/eggnog_database/.setup.done"
	params:
		database = config["eggnog_database"],
		location = config["eggnog_database_path"],
		wd = os.getcwd()
	singularity:
		config["containers"]["eggnog_mapper"]
	shell:
		"""
		if [[ -d {params.location} ]]; then
			echo "A directory for eggnog db was provided. Will first check a database is already present at this location".
			if [[ -f {params.location}/eggnog.db && -f {params.location}/eggnog_proteins.dmnd && -f {params.location}/og2level.tsv.gz && -d {params.location}/hmmdb_levels && -d {params.location}/OG_fasta ]]; then
				echo "Good. {params.location}/eggnog.db is present."
				echo "Good. {params.location}/eggnog_proteins.dmnd is present."
				echo "Good. {params.location}/og2level.tsv.gz is present."
				echo "Good. {params.location}/hmmdb_levels is present."
				echo "Good. {params.location}/OG_fasta is present."
				echo "This looks like a genuine Eggnog Database. Will not download anything but will symlink the database to data/eggnogdb"
				ln -s {params.wd}/{params.location} data/eggnogdb
				touch {output}
			else
				echo "It does not seem like an Eggnog Database is available at {params.location}."
			fi
		else
			echo "No specific location was provided for the Eggnog DB (or the directory does not exist). Will use data/eggnogdb"
			if [[ -f {params.wd}/data/eggnogdb/eggnog.db && -f {params.wd}/data/eggnogdb/eggnog_proteins.dmnd && -f {params.wd}/data/eggnogdb/og2level.tsv.gz && -d {params.wd}/data/eggnogdb/hmmdb_levels && -d {params.wd}/data/eggnogdb/OG_fasta ]]; then
				echo "Good. {params.wd}/data/eggnogdb/eggnog.db is present."
				echo "Good. {params.wd}/data/eggnogdb/eggnog_proteins.dmnd is present."
				echo "Good. {params.wd}/data/eggnogdb/og2level.tsv.gz is present."
				echo "Good. {params.wd}/data/eggnogdb/hmmdb_levels is present."
				echo "Good. {params.wd}/data/eggnogdb/OG_fasta is present."
				echo "This looks like a genuine Eggnog Database. Will not download anything."
				touch {output}
			else
				echo "Will download database now. Please be patient, this can take several minutes."
				mkdir -p {params.wd}/data/eggnogdb
				download_eggnog_data.py {params.database} -y --data_dir data/eggnogdb
				touch {output}
			fi
		fi
		"""
