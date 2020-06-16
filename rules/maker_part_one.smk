rule initiate:
	input:
		rules.setup_maker.output
	params:
		prefix = "{sample}"
	output:
		"results/{sample}/{sample}.ok"
	shell:
		"""
		if [[ ! -d results/{params.prefix} ]]
		then
			mkdir results/{params.prefix}
		fi
		touch {output}
		"""

rule split:
	input:
		fasta = get_assembly_path,
		ok = rules.initiate.output
	params:
		prefix = "{sample}",
		len = n,
		min = min
	log:
		stdout = "results/{sample}/logs/split.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/split.{sample}.stderr.txt"
	output:
		ok = "results/{sample}/GENOME_PARTITIONS/splitting.ok",
		fasta = "results/{sample}/GENOME_PARTITIONS/{sample}.min"+str(min)+".fasta"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
		basedir=$(pwd)

		cd results/{params.prefix}/GENOME_PARTITIONS/
		bash $basedir/bin/count_length.sh ../../../{input.fasta} {params.len} {params.min} split

		retVal=$?

                if [ ! $retVal -eq 0 ]
                then
                        echo "Splitting ended in an error"
                        exit $retVal
                else
                        touch ../../../{output.ok}
			cat *.fasta > ../../../{output.fasta}
                fi

		echo -e "\n$(date)\tFinished!\n"
		"""

rule genemark:
	input:
		ok = rules.initiate.output,
		fasta = rules.split.output.fasta
	params:
		prefix = "{sample}",
		genemark_dir = config["genemark"]["genemark_dir"],
		gmes_petap_params = config["genemark"]["gmes_petap_params"]
	threads: config["threads"]["genemark"]
	singularity:
		"docker://chrishah/premaker-plus:18"
	log:
		stdout = "results/{sample}/logs/GENEMARK.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/GENEMARK.{sample}.stderr.txt"
	output:
		ok = "results/{sample}/GENEMARK/genemark.status.ok",
		model = "results/{sample}/GENEMARK/gmhmm.mod"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
		basedir=$(pwd)

                if [[ ! -d results/{params.prefix}/GENEMARK ]]
                then
                        mkdir results/{params.prefix}/GENEMARK
		else
			if [ "$(ls -1 results/{params.prefix}/GENEMARK/ | wc -l)" -gt 0 ]
			then
				echo -e "Cleaning up remnants of previous run first" 1> {log.stdout} 2> {log.stderr}
				rm results/{params.prefix}/GENEMARK
				mkdir results/{params.prefix}/GENEMARK
			fi
                fi
                cd results/{params.prefix}/GENEMARK

		ln -sf $basedir/{params.genemark_dir}/gm_key .gm_key

		if [ "{params.gmes_petap_params}" == "None" ]
		then
			gmes_petap.pl -ES -cores {threads} -sequence ../../../{input.fasta} 1> ../../../{log.stdout} 2> ../../../{log.stderr}
		else
			gmes_petap.pl -ES {params.gmes_petap_params} -cores {threads} -sequence ../../../{input.fasta} 1> ../../../{log.stdout} 2> ../../../{log.stderr}
		fi

		retVal=$?

		if [ ! $retVal -eq 0 ]
		then
			echo "Genemark ended in an error"
			exit $retVal
		else
			touch ../../../{output.ok}
		fi
		echo -e "\n$(date)\tFinished!\n"
		
		"""		
		
rule busco:
	input:
		ok = rules.initiate.output,
		fasta = rules.split.output.fasta
	params:
		prefix = "{sample}",
		busco_path = "data/BUSCO",
		busco_set = config["busco"]["set"],
		augustus_species = config["busco"]["species"]
	threads: config["threads"]["busco"]
	singularity:
		"docker://chrishah/busco-docker:v3.1.0"
	log:
		stdout = "results/{sample}/logs/BUSCO.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/BUSCO.{sample}.stderr.txt"
	output:
		"results/{sample}/BUSCO/run_{sample}/single_copy_busco_sequences/{sample}.BUSCOs.fasta"
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

		cp -rf /usr/share/augustus/config tmp/config
		AUGUSTUS_CONFIG_PATH=$(pwd)/tmp/config

		#run BUSCO
		run_BUSCO.py \
		--in ../../../{input.fasta} --out {params.prefix} -l ../../../{params.busco_path}/{params.busco_set} --mode genome -c {threads} -f \
		-sp {params.augustus_species} --long --augustus_parameters='--progress=true' 1> ../../../{log.stdout} 2> ../../../{log.stderr}

		#collect predicted BUSCOs
		cat run_{params.prefix}/single_copy_busco_sequences/*.faa | sed 's/:.*//' > run_{params.prefix}/single_copy_busco_sequences/{params.prefix}.BUSCOs.fasta

		echo -e "\n$(date)\tFinished!\n"
		"""

rule cegma:
	input:
		ok = rules.initiate.output,
		fasta = rules.split.output.fasta
	params:
		prefix = "{sample}"
	threads: config["threads"]["cegma"]
	singularity:
		"docker://chrishah/cegma:2.5"
	log:
		stdout = "results/{sample}/logs/CEGMA.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/CEGMA.{sample}.stderr.txt"
	output:
		ok = "results/{sample}/CEGMA/cegma.status.ok",
		cegma_gff = "results/{sample}/CEGMA/{sample}.cegma.gff"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"

		if [[ ! -d results/{params.prefix}/CEGMA ]]
		then
			mkdir results/{params.prefix}/CEGMA
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
		fasta = rules.split.output.fasta
	params:
		prefix = "{sample}",
		script = "bin/snap.p1.sh"
	singularity:
		"docker://chrishah/premaker-plus:18"
	log:
		stdout = "results/{sample}/logs/SNAP.PASS1.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/SNAP.PASS1.{sample}.stderr.txt"
	output:
		ok = "results/{sample}/SNAP.PASS1/snap.status.ok",
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

