rule setup_ncbi_check:
	output:
		db = "data/ncbi-fcs-db/db/check.ok",
	container: "docker://ncbi/fcs-gx:0.2.3"
	params:
		whichdb = config["assembly_cleanup"]["contaminant_database"] 
	shell:
		"""
		SHM_LOC="$(pwd)/"$(dirname {output.db})
		dbpath=$SHM_LOC"/local"
		mkdir -p $SHM_LOC/local
		python3 /app/bin/retrieve_db --gx-db $SHM_LOC/local/{params.whichdb} --gx-db-disk $SHM_LOC
		touch {output}
		"""

# singularity exec --bind /cl_tmp/reslph/projects/annocomba-monos/data/ncbi-fcs-db/local:/app/db/gxdb --bind /cl_tmp/reslph/projects/annocomba-monos/data/ncbi-fcs-db/db:/db-disk-volume/ docker://ncbi/fcs-gx:0.2.3 python3 /app/bin/retrieve_db --gx-db /app/db/gxdb/test-only --gx-db-disk /db-disk-volume/

