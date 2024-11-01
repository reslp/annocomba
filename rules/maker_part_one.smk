#rule initiate:
#	input:
#		rules.setup_maker.output
#	params:
#		prefix = "{sample}"
#	output:
#		"results/{sample}/{sample}.ok"
#	shell:
#		"""
#		if [[ ! -d results/{params.prefix} ]]
#		then
#			mkdir results/{params.prefix}
#		fi
#		touch {output}
#
#		"""
#rule split:
#	input:
#		fasta = get_assembly_path,
#	params:
#		prefix = "{sample}",
#		len = n,
#		min = min
#	log:
#		stdout = "results/{sample}/logs/split.{sample}.stdout.txt",
#		stderr = "results/{sample}/logs/split.{sample}.stderr.txt"
#	output:
#		ok = "results/{sample}/GENOME_PARTITIONS/splitting.ok",
#		fasta = "results/{sample}/GENOME_PARTITIONS/{sample}.min"+str(min)+".fasta"
#	shell:
#		"""
#		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
#		basedir=$(pwd)
#
#		cd results/{params.prefix}/GENOME_PARTITIONS/
#		bash $basedir/bin/count_length.sh ../../../{input.fasta} {params.len} {params.min} split
#
#		retVal=$?
#
#               if [ ! $retVal -eq 0 ]
#               then
#                        echo "Splitting ended in an error"
#                        exit $retVal
#                else
#                        touch ../../../{output.ok}
#			cat *.fasta > ../../../{output.fasta}
#                fi
#
#		echo -e "\n$(date)\tFinished!\n"
#		"""


rule split:
	input:
		assembly = rules.sort.output.assembly
	output:
		checkpoint = "checkpoints/{sample}/split.ok",
	singularity:
		config["containers"]["funannotate"]
	params:
		n_batches = get_batch_number,
		wd = os.getcwd(),
		fastas = "results/{sample}/GENOME_PARTITIONS/"
	shell:
		"""
		if [[ -d {params.fastas} ]]; then
			rm -rf {params.fastas}
		fi
		mkdir {params.fastas}
		cd {params.fastas}
		{params.wd}/bin/split_fasta.py {params.wd}/{input} {params.n_batches}
		cd {params.wd}
		touch {output.checkpoint}
		"""

rule download_busco_set:
	output:
		busco_set = directory("databases/busco/"+config["busco_set"]),
	params:
		set = config["busco_set"],
	log:
		"log/setup/download_busco_set.log"
	shell:
		"""
		echo -e "[$(date)]\\tBUSCO set specified: {params.set}" 2>&1 | tee {log}
		if [ -d {output.busco_set} ]; then rm -rf {output.busco_set}; fi
		mkdir {output.busco_set}

		base_url="https://busco-data.ezlab.org/v5/data/lineages"
		current=$(curl -s $base_url/ | grep "{params.set}" | cut -d ">" -f 2 | sed 's/<.*//')
		echo -e "[$(date)]\\tCurrent version is: $current" 2>&1 | tee -a {log}
		echo -e "[$(date)]\\tDownloading .." 2>&1 | tee -a {log}
		wget -q -c $base_url/$current -O - --no-check-certificate | tar -xz --strip-components 1 -C {output.busco_set}/

		echo -ne "[$(date)]\\tDone!\\n" 2>&1 | tee -a {log}
		"""
rule busco:
	input:
		fasta = rules.sort.output.assembly,
		busco_set = rules.download_busco_set.output
	params:
		prefix = "{sample}",
		augustus_species = config["busco_species"],
		augustus_config_in_container = "/usr/local/config",
		busco_set = config["busco_set"],
		wd = os.getcwd(),
	threads: config["threads"]["busco"]
	singularity:
		config["containers"]["busco"]
	log:
		stdout = "results/{sample}/logs/BUSCO.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/BUSCO.{sample}.stderr.txt"
	output:
		buscos = "results/{sample}/BUSCO/{sample}.BUSCOs.fasta",
		ok = "checkpoints/{sample}/busco.status.ok"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"

		if [[ -d results/{params.prefix}/BUSCO ]]
		then
			rm -rf results/{params.prefix}/BUSCO
		fi
		mkdir results/{params.prefix}/BUSCO
		cd results/{params.prefix}/BUSCO

		if [[ ! -d tmp ]]
		then
			mkdir tmp
		fi

		cp -rf {params.augustus_config_in_container} tmp/config
		#cp -rf /opt/conda/config tmp/config
		export AUGUSTUS_CONFIG_PATH=$(pwd)/tmp/config

		if [[ {params.augustus_species} == "auto" ]] || [[ {params.augustus_species} == "None" ]]
		then
			aug_sp=""
		else
			aug_sp="--augustus_species {params.augustus_species}"
		fi

		#run BUSCO
		busco -i ../../../{input.fasta} -f --out {params.prefix} -c {threads} --mode genome --lineage_dataset {params.wd}/{input.busco_set} \
		--augustus --long $aug_sp --augustus_parameters='--progress=true' 1> ../../../{log.stdout} 2> ../../../{log.stderr}
#		--augustus $aug_sp --augustus_parameters='--progress=true' 1> ../../../{log.stdout} 2> ../../../{log.stderr}
 
		#collect predicted BUSCOs
		cat {params.prefix}/run_{params.busco_set}/busco_sequences/single_copy_busco_sequences/*.faa | sed 's/ .*//' | sed 's/:/|/' > {params.prefix}.BUSCOs.fasta

		echo -e "\n$(date)\tFinished!\n"
		touch {params.wd}/{output.ok}	
		"""

rule cegma:
	input:
		fasta = rules.sort.output.assembly
	params:
		prefix = "{sample}"
	threads: config["threads"]["cegma"]
	singularity:
		config["containers"]["cegma"]
	log:
		stdout = "results/{sample}/logs/CEGMA.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/CEGMA.{sample}.stderr.txt"
	output:
		ok = "checkpoints/{sample}/cegma.status.ok",
		cegma_gff = "results/{sample}/CEGMA/{sample}.cegma.gff"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"

		if [[ "$(ls -1 results/{params.prefix}/CEGMA/ | wc -l)" -gt 0 ]]
		then
			rm results/{params.prefix}/CEGMA/*
		fi
		cd results/{params.prefix}/CEGMA

		#run CEGMA
		cegma -g ../../../{input.fasta} -T {threads} -o {params.prefix} 1> ../../../{log.stdout} 2> ../../../{log.stderr}

		retVal=$?

		if [ ! $retVal -eq 0 ]
		then
			echo "Cegma ended in an error"
			exit $retVal
		else
			touch ../../../{output.ok}
		fi
		echo -e "\n$(date)\tFinished!\n"

		"""

rule snap_pass1:
	input:
		ok = rules.cegma.output.ok,
		cegma_gff = rules.cegma.output.cegma_gff,
		fasta = rules.sort.output.assembly
	params:
		prefix = "{sample}",
		script = "bin/snap.p1.sh"
	singularity:
		config["containers"]["premaker"]
	log:
		stdout = "results/{sample}/logs/SNAP.PASS1.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/SNAP.PASS1.{sample}.stderr.txt"
	output:
		ok = "checkpoints/{sample}/snap_pass1.status.ok",
		hmm = "results/{sample}/SNAP.PASS1/{sample}.cegma.snap.hmm"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
		basedir=$(pwd)
		
		export PATH="$(pwd)/bin/maker/bin:$PATH"

		if [[ ! -d results/{params.prefix}/SNAP.PASS1 ]]
		then
			mkdir results/{params.prefix}/SNAP.PASS1
		fi
		cd results/{params.prefix}/SNAP.PASS1

		bash $basedir/{params.script} \
		{params.prefix} \
		$basedir/{input.cegma_gff} \
		$basedir/{input.fasta} \
		1> $basedir/{log.stdout} 2> $basedir/{log.stderr}

		retVal=$?

		if [ ! $retVal -eq 0 ]
		then
			echo "SNAP ended in an error"
			exit $retVal
		else
			touch $basedir/{output.ok}
		fi
		echo -e "\n$(date)\tFinished!\n"
		"""

