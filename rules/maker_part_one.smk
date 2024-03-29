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
		
rule busco:
	input:
		fasta = rules.sort.output.assembly
	params:
		prefix = "{sample}",
		busco_path = "data/funannotate_database",
		busco_set = config["busco_set"],
		augustus_species = config["busco_species"],
		wd = os.getcwd(),
		busco_tblastn_single_core = config["busco_tblastn_single_core"]
	threads: config["threads"]["busco"]
	singularity:
		config["containers"]["busco"]
	log:
		stdout = "results/{sample}/logs/BUSCO.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/BUSCO.{sample}.stderr.txt"
	output:
		buscos = "results/{sample}/BUSCO/run_{sample}/single_copy_busco_sequences/{sample}.BUSCOs.fasta",
		ok = "checkpoints/{sample}/busco.status.ok"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"

		if [[ ! -d results/{params.prefix}/BUSCO ]]
		then
			mkdir results/{params.prefix}/BUSCO
		fi
		cd results/{params.prefix}/BUSCO

		if [[ ! -d tmp ]]
		then
			mkdir tmp
		fi

		cp -rf /opt/conda/config tmp/config
		AUGUSTUS_CONFIG_PATH=$(pwd)/tmp/config

		#check if tblastn single core flag is set:
		if [[ "{params.busco_tblastn_single_core}" == "yes" ]]; then
			SCF="--blast_single_core"
		else
			SCF=""
		fi

		#run BUSCO
		run_BUSCO.py \
		--in ../../../{input.fasta} --out {params.prefix} -l ../../../{params.busco_path}/{params.busco_set} --mode genome -c {threads} -f \
		-sp {params.augustus_species} --long --augustus_parameters='--progress=true' $SCF 1> ../../../{log.stdout} 2> ../../../{log.stderr}

		#collect predicted BUSCOs
		cat run_{params.prefix}/single_copy_busco_sequences/*.faa | sed 's/:.*//' > run_{params.prefix}/single_copy_busco_sequences/{params.prefix}.BUSCOs.fasta

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

