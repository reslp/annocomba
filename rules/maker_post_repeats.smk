rule prepare_protein_evidence:
	input:
		proteins = expand("{full}/{file}", full=[os.getcwd()], file=glob.glob("data/protein_evidence/*.gz")),
	params:
		prefix = "{sample}",
		mem = "8000",
		similarity = config["cdhit"]["similarity"]
	threads: config["threads"]["prepare_protein_evidence"]
	singularity:
		"docker://chrishah/cdhit:v4.8.1"
	log:
		stdout = "results/{sample}/logs/CDHIT.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/CDHIT.{sample}.stderr.txt"
	output:
		ok = "checkpoints/{sample}/nr_protein_evidence.status.ok",
		nr_proteins = "results/{sample}/NR_PROTEIN_EVIDENCE/nr_external_proteins.cd-hit.fasta"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"

		if [[ ! -d results/{params.prefix}/NR_PROTEIN_EVIDENCE ]]
		then
			mkdir results/{params.prefix}/NR_PROTEIN_EVIDENCE
		fi
		cd results/{params.prefix}/NR_PROTEIN_EVIDENCE

		echo -e "Remove redundancy at {params.similarity} in files:\n{input.proteins}"

		#concatenate all physical evidence
		cat {input.proteins} > external_proteins.fasta.gz

		#run cd-hit
		cd-hit -T {threads} -M {params.mem} -i external_proteins.fasta.gz -o external_proteins.cd-hit-{params.similarity}.fasta -c {params.similarity} 1> ../../../{log.stdout} 2> ../../../{log.stderr}
		retVal=$?

		ln -s external_proteins.cd-hit-{params.similarity}.fasta ../../../{output.nr_proteins}

		#remove obsolete file
		rm external_proteins.fasta.gz


		if [ ! $retVal -eq 0 ]
		then
			echo "There was some error"
			exit $retVal
		else
			touch ../../../{output.ok}
		fi
		echo -e "\n$(date)\tFinished!\n"
		"""

rule genemark:
	input:
		fasta = rules.mask_repeats.output.hard
#		fasta = rules.sort.output.assembly
	params:
		prefix = "{sample}",
		genemark_dir = config["genemark"]["genemark_dir"],
		gmes_petap_params = config["genemark"]["gmes_petap_params"],
		wd = os.getcwd()
	threads: config["threads"]["genemark"]
	singularity:
		config["containers"]["premaker"]
	log:
		stdout = "results/{sample}/logs/GENEMARK.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/GENEMARK.{sample}.stderr.txt"
	output:
		ok = "checkpoints/{sample}/genemark.status.ok",
		model = "results/{sample}/GENEMARK/gmhmm.mod"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
		export PATH="{params.wd}/{params.genemark_dir}:$PATH"
                
		if [[ ! -d results/{params.prefix}/GENEMARK ]]
                then
                        mkdir results/{params.prefix}/GENEMARK
		else
			if [ "$(ls -1 results/{params.prefix}/GENEMARK/ | wc -l)" -gt 0 ]
			then
				echo -e "Cleaning up remnants of previous run first" 1> {log.stdout} 2> {log.stderr}
				rm -rf results/{params.prefix}/GENEMARK
				mkdir results/{params.prefix}/GENEMARK
			fi
                fi
                cd results/{params.prefix}/GENEMARK

		# can this be done as part of setup? perhaps not, since this place does not yet exist on setup
		ln -sf {params.wd}/{params.genemark_dir}/gm_key .gm_key

		if [ "{params.gmes_petap_params}" == "None" ]
		then
			gmes_petap.pl -ES -cores {threads} -sequence {params.wd}/{input.fasta} 1> {params.wd}/{log.stdout} 2> {params.wd}/{log.stderr}
		else
			gmes_petap.pl -ES {params.gmes_petap_params} -cores {threads} -sequence {params.wd}/{input.fasta} 1> {params.wd}/{log.stdout} 2> {params.wd}/{log.stderr}
		fi

		retVal=$?

		if [ ! $retVal -eq 0 ]
		then
			echo "Genemark ended in an error"
			exit $retVal
		else
			touch {params.wd}/{output.ok}
		fi
		echo -e "\n$(date)\tFinished!\n"
		
		"""		
		
rule initiate_MAKER_PASS1:
	input:
		ok = rules.split.output.checkpoint,
		snap = rules.snap_pass1.output.hmm,
		nr_evidence = rules.prepare_protein_evidence.output.nr_proteins,
		busco_proteins = rules.busco.output.buscos,
		repmod_lib = rules.repeatmodeler.output.fasta,
		repmas_gff_denovo = rules.repeatmasker_denovo.output.gff,
		repmas_gff = rules.repeatmasker.output.gff
	params:
		prefix = "{sample}",
		transcripts = get_transcripts_path,
		script = "bin/prepare_maker_opts_PASS1.sh"
	singularity:
		"docker://chrishah/premaker-plus:18"
	log:
		stdout = "results/{sample}/logs/MAKER.PASS1.init.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/MAKER.PASS1.init.{sample}.stderr.txt"
	output:
		ok = "checkpoints/{sample}/MAKER_PASS1_init.ok"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
		basedir=$(pwd)
		export PATH="$(pwd)/bin/maker/bin:$PATH"


		if [[ ! -d results/{params.prefix}/MAKER.PASS1 ]]
		then
			mkdir results/{params.prefix}/MAKER.PASS1
		fi
		cd results/{params.prefix}/MAKER.PASS1

		maker -CTL 1> $basedir/{log.stdout} 2> $basedir/{log.stderr}
		retVal=$?
		
		#quick check to see if NR protein evidence file is empty
		if [[ -s $basedir/{input.nr_evidence} ]]; then
			nr_evi=$basedir/{input.nr_evidence}
		else
			nr_evi=""
		fi

		##### Modify maker_opts.ctl file
		bash $basedir/{params.script} \
		$basedir/{input.snap} \
		$nr_evi \
		$basedir/{input.busco_proteins} \
		$basedir/{input.repmod_lib} \
		$basedir/{input.repmas_gff},$basedir/{input.repmas_gff_denovo} \
		"{params.transcripts[alt_ests]}" \
		"{params.transcripts[ests]}" \
		1> $basedir/{log.stdout} 2> $basedir/{log.stderr}
		
		retVal=$(( retVal + $? ))


		if [ ! $retVal -eq 0 ]
		then
			echo "There was some error" >> $basedir/{log.stderr}
			exit $retVal
		else
			touch $basedir/{output.ok}
		fi
		echo -e "\n$(date)\tFinished!\n"
		"""

rule run_MAKER_PASS1:
	input:
		init_ok = rules.initiate_MAKER_PASS1.output.ok,
		split_ok = rules.split.output.checkpoint
	params:
		dir = "{unit}",
		prefix = "{sample}",
		sub = "results/{sample}/GENOME_PARTITIONS/{unit}.fasta"
	threads: config["threads"]["run_MAKER_PASS1"]
	shadow: "shallow"
	singularity:
		"docker://chrishah/premaker-plus:18"
	log:
		stdout = "results/{sample}/logs/MAKER.PASS1.run.{sample}.{unit}.stdout.txt",
		stderr = "results/{sample}/logs/MAKER.PASS1.run.{sample}.{unit}.stderr.txt"
	output:
		#sub_fasta = "results/{sample}/MAKER.PASS1/{unit}/{sample}.{unit}.fasta",
		prot_fasta = "results/{sample}/MAKER.PASS1/{unit}/{sample}.{unit}.all.maker.proteins.fasta",
		transcripts_fasta = "results/{sample}/MAKER.PASS1/{unit}/{sample}.{unit}.all.maker.transcripts.fasta",
		gff = "results/{sample}/MAKER.PASS1/{unit}/{sample}.{unit}.all.maker.gff",
		noseq_gff = "results/{sample}/MAKER.PASS1/{unit}/{sample}.{unit}.noseq.maker.gff",
		ok = "checkpoints/{sample}/MAKER.PASS1.{unit}.ok"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"

		basedir=$(pwd)
		export PATH="$(pwd)/bin/maker/bin:$PATH"

		mkdir {params.dir}
		cd {params.dir}
		ln -s $basedir/{params.sub} {params.prefix}.{params.dir}.fasta

		#run MAKER
		maker -base {params.prefix}.{params.dir} -g {params.prefix}.{params.dir}.fasta -nolock -c {threads} $basedir/results/{params.prefix}/MAKER.PASS1/maker_opts.ctl $basedir/results/{params.prefix}/MAKER.PASS1/maker_bopts.ctl $basedir/results/{params.prefix}/MAKER.PASS1/maker_exe.ctl 1> $basedir/{log.stdout} 2> $basedir/{log.stderr}

		#prepare data from MAKER 
		cd {params.prefix}.{params.dir}.maker.output
		gff3_merge -d {params.prefix}.{params.dir}_master_datastore_index.log -o {params.prefix}.{params.dir}.all.maker.gff
		fasta_merge -d {params.prefix}.{params.dir}_master_datastore_index.log
		gff3_merge -n -d {params.prefix}.{params.dir}_master_datastore_index.log -o {params.prefix}.{params.dir}.noseq.maker.gff

		#ln -s $basedir/{params.sub} $basedir/results/{params.prefix}/MAKER.PASS1/{params.dir}
		mv {params.prefix}.{params.dir}.all.maker.* $basedir/results/{params.prefix}/MAKER.PASS1/{params.dir}
		mv {params.prefix}.{params.dir}.noseq.maker.* $basedir/results/{params.prefix}/MAKER.PASS1/{params.dir}
	
		touch $basedir/{output.ok}	
		echo -e "\n$(date)\tFinished!\n"
		"""

#rule cleanup_MAKER_PASS1:
#	input:
#		rules.run_MAKER_PASS1.output
#	params:
#		dir = "{unit}",
#		prefix = "{sample}",
#		script = "bin/cleanup.sh"
#	singularity:
#		"docker://chrishah/premaker-plus:18"
#	output:
#		gzipped_results = "results/{sample}/MAKER.PASS1/{unit}/{sample}.{unit}.maker.output.tar.gz",
#		ok = "checkpoints/{sample}/cleanup_MAKER_PASS1.{unit}.ok"
#	shell:
#		"""
#		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
#		basedir=$(pwd)
#		
#		cd results/{params.prefix}/MAKER.PASS1/{params.dir}/
#		bash $basedir/{params.script} {params.prefix}.{params.dir}.maker.output
#		touch $basedir/{output.ok}
#		echo -e "\n$(date)\tFinished!\n"
#
#		"""	

rule merge_MAKER_PASS1:
	input:
		lambda wildcards: expand("results/{{sample}}/MAKER.PASS1/{unit}/{{sample}}.{unit}.all.maker.gff", sample=wildcards.sample, unit=unitdict[wildcards.sample])
#		expand("results/{{sample}}/MAKER.PASS1/{unit.unit}/{{sample}}.{unit.unit}.fasta", sample=samples.index.tolist(), unit=units.itertuples())
	params:
		prefix = "{sample}",
		script = "bin/merging.sh"
	singularity:
		"docker://chrishah/premaker-plus:18"
	output:
		all_gff = "results/{sample}/MAKER.PASS1/{sample}.all.maker.gff",
		noseq_gff = "results/{sample}/MAKER.PASS1/{sample}.noseq.maker.gff",
		proteins = "results/{sample}/MAKER.PASS1/{sample}.all.maker.proteins.fasta",
		ok = "checkpoints/{sample}/merge_MAKER_PASS1.ok"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
		export PATH="$(pwd)/bin/maker/bin:$PATH"
		basedir=$(pwd)
		cd results/{params.prefix}/MAKER.PASS1/

		bash $basedir/{params.script} {params.prefix}
		
		touch $basedir/{output.ok}	
		echo -e "\n$(date)\tFinished!\n"
		"""

rule AUGUSTUS_PASS2:
	input:
		busco_ok = rules.busco.output,
		fasta = rules.mask_repeats.output.hard,
		maker_proteins = rules.merge_MAKER_PASS1.output.proteins
	params:
		prefix = "{sample}",
		training_params = "results/{sample}/BUSCO/run_{sample}/augustus_output/retraining_parameters",
		script = "bin/augustus.PASS2.sh",
		aed = "{aed}",
		transcripts = get_transcripts_path 
	threads: config["threads"]["AUGUSTUS_PASS2"]
	singularity:
		"docker://chrishah/augustus:v3.3.2"
	log:
		stdout = "results/{sample}/logs/AUGUSTUS.PASS2.{aed}.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/AUGUSTUS.PASS2.{aed}.{sample}.stderr.txt"
	output:
		ok = "checkpoints/{sample}/{aed}.augustus.ok",
		training_params = directory("results/{sample}/AUGUSTUS.PASS2/{aed}/{aed}.{sample}")
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
		basedir=$(pwd)
		
		echo -e "TODO: CHECK FOR cDNA evidence and include in autoAug.pl run via --cdna=cdna.fa option - see 'Typical Usage' in Readme of autoAug.pl script"		
		echo -e "TODO: RUN Augustus across a range of aed cutoffs and use the one that has the best prediction accuracy"		

		if [[ ! -d results/{params.prefix}/AUGUSTUS.PASS2 ]]
		then
			mkdir results/{params.prefix}/AUGUSTUS.PASS2/
		fi
		cd results/{params.prefix}/AUGUSTUS.PASS2/

		if [[ ! -d {params.aed} ]]
		then
			mkdir {params.aed}
		fi
		cd {params.aed}

		if [[ ! -d tmp.{params.aed} ]]
		then
			mkdir tmp.{params.aed}
		fi
		
		#copy augustus config directory from the image
		cp -rf /usr/share/augustus/config tmp.{params.aed}/config

		est="{params.transcripts[ests]}"
		if [ ! -z "$est" ]
		then
			cat $est > cdna.{params.aed}.fasta	
		fi

		bash $basedir/{params.script} \
		{threads} \
		{params.aed}.{params.prefix} \
		$basedir/{input.fasta} \
		$basedir/{input.maker_proteins} \
		{params.aed} \
		$(pwd)/tmp.{params.aed}/config \
		$basedir/{params.training_params} \
		cdna.{params.aed}.fasta \
		1> $basedir/{log.stdout} 2> $basedir/{log.stderr}

		retVal=$?

		#rm -rf tmp.{params.aed}/

		if [ ! $retVal -eq 0 ]
		then
			>&2 echo "Augustus ended in an error" >> $basedir/{log.stderr}
			#exit $retVal
                        # touch the output file here is only a dirty workaround for when the augustus training script
                        # fails. This only happens on sauron. The subsequent rules should not care about how many
                        # successful runs of augustus training were produced. Nontheless this very ugly und should be
                        # handled better.
                        touch $basedir/{output.ok}
		else
			touch $basedir/{output.ok}
		fi
		echo -e "\n$(date)\tFinished!\n"

		"""
rule pick_augustus_training_set:
	input:
		lambda wildcards: expand("checkpoints/{{sample}}/{aed}.augustus.ok", sample=wildcards.sample, aed=config["aed"]["AUGUSTUS_PASS2"])
	params:
		aeds = expand("{aed}", aed=config["aed"]["AUGUSTUS_PASS2"]),
		prefix = "{sample}",
		best_params = "results/{sample}/AUGUSTUS.PASS2/training_params",
		gff = "results/{sample}/AUGUSTUS.PASS2/{sample}.final.gff3",
		best_aed = "results/{sample}/AUGUSTUS.PASS2/{sample}.best_aed"
	output:
		ok = "checkpoints/{sample}/pick_augustus_training_set.ok"
	singularity:
		"docker://chrishah/premaker-plus:18"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"

		echo -e "{input}" 
		echo -e "{params.aeds}"
		for aed in $(echo -e "{params.aeds}")
		do
			echo -e "$aed\t$(grep "accuracy after optimizing" results/{params.prefix}/logs/AUGUSTUS.PASS2.$aed.{params.prefix}.stdout.txt | rev | cut -d " " -f 1 | rev)"
		done > results/{params.prefix}/AUGUSTUS.PASS2/summary.tsv

		best=$(cat results/{params.prefix}/AUGUSTUS.PASS2/summary.tsv | tr . , | sort -n -k 2 | cut -f 1 | tr , . | tail -n 1)
		echo "{params.prefix}: Best training accuracy was achieved with cutoff $best"

		ln -sf $(pwd)/results/{params.prefix}/AUGUSTUS.PASS2/$best/$best.{params.prefix} {params.best_params}
		
		#mkdir {params.best_params}
		#for f in $(ls -1 results/{params.prefix}/AUGUSTUS.PASS2/$best/$best.{params.prefix}/)
		#do
		#	ln -s $(pwd)/results/{params.prefix}/AUGUSTUS.PASS2/$best/$best.{params.prefix}/$f {params.best_params}/$(echo "$f" | sed "s/^$best.//")
		#done
		
		ln -sf $(pwd)/results/{params.prefix}/AUGUSTUS.PASS2/$best/augustus.gff3 {params.gff}
		echo "$best" > {params.best_aed}
		touch {output.ok}
		
		echo -e "\n$(date)\tFinished!\n"
		"""

rule snap_pass2:
	input:
		rules.merge_MAKER_PASS1.output.all_gff,
		rules.pick_augustus_training_set.output.ok
	params:
#		aed = config["aed"]["snap_pass2"],
		prefix = "{sample}",
		script = "bin/snap.p2.sh"
	singularity:
		"docker://chrishah/premaker-plus:18"
	log:
		stdout = "results/{sample}/logs/SNAP.PASS2.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/SNAP.PASS2.{sample}.stderr.txt"
	output:
		snap_hmm = "results/{sample}/SNAP.PASS2/{sample}.MAKER_PASS1.snap.hmm",
		ok = "checkpoints/{sample}/snap_pass2.ok"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
		basedir=$(pwd)
		
		export PATH="$(pwd)/bin/maker/bin:$PATH"

		#get best aed cutoff from AUGUSTUS
		aed=$(cat results/{params.prefix}/AUGUSTUS.PASS2/{params.prefix}.best_aed)

		if [[ ! -d results/{params.prefix}/SNAP.PASS2 ]]
		then
			mkdir results/{params.prefix}/SNAP.PASS2/
		fi
		cd results/{params.prefix}/SNAP.PASS2/

		bash $basedir/{params.script} \
		{params.prefix} \
		$basedir/{input[0]} \
		$aed \
		1> $basedir/{log.stdout} 2> $basedir/{log.stderr}
		touch $basedir/{output.ok}
		echo -e "\n$(date)\tFinished!\n"
		"""

rule initiate_MAKER_PASS2:
	input:
		snaphmm = rules.snap_pass2.output.snap_hmm,
		MP1_ok = rules.merge_MAKER_PASS1.output,
		gmhmm = rules.genemark.output.model
	params:
		prefix = "{sample}",
		script = "bin/prepare_maker_opts_PASS2.sh",
		protein_gff = "results/{sample}/MAKER.PASS1/{sample}.noseq.maker.protein2genome.gff",
		rm_gff = "results/{sample}/MAKER.PASS1/{sample}.noseq.maker.repeats.gff",
		altest_gff = "results/{sample}/MAKER.PASS1/{sample}.noseq.maker.cdna2genome.gff",
		est_gff = "results/{sample}/MAKER.PASS1/{sample}.noseq.maker.est2genome.gff",
		pred_gff = "results/{sample}/AUGUSTUS.PASS2/{sample}.final.gff",
		params = "results/{sample}/AUGUSTUS.PASS2/training_params",
		best_aed = "results/{sample}/AUGUSTUS.PASS2/{sample}.best_aed"
	singularity:
		"docker://chrishah/premaker-plus:18"
	log:
		stdout = "results/{sample}/logs/MAKER.PASS2.init.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/MAKER.PASS2.init.{sample}.stderr.txt"
	output:
		ok = "checkpoints/{sample}/MAKER.PASS2.init.ok"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
		basedir=$(pwd)
		export PATH="$(pwd)/bin/maker/bin:$PATH"
		aed=$(cat {params.best_aed})

		if [[ ! -d results/{params.prefix}/MAKER.PASS2 ]]
		then
			mkdir results/{params.prefix}/MAKER.PASS2
		fi
		cd results/{params.prefix}/MAKER.PASS2

		maker -CTL 1> $basedir/{log.stdout} 2> $basedir/{log.stderr}
		retVal=$?

		if [[ ! -d tmp ]]
		then
			mkdir tmp
		fi
		#copy augustus config directory from the image
		cp -rf /usr/share/augustus/config tmp/config

		##### Modify maker_opts.ctl file
		bash $basedir/{params.script} \
		$basedir/{input.snaphmm} \
		$basedir/{input.gmhmm} \
		$aed.{params.prefix} \
		$basedir/{params.params} \
		$basedir/{params.pred_gff} \
		$basedir/{params.rm_gff} \
		$basedir/{params.protein_gff} \
		$basedir/{params.altest_gff} \
		$basedir/{params.est_gff} \
		$(pwd)/tmp/config \
		1> $basedir/{log.stdout} 2> $basedir/{log.stderr}
		
		retVal=$(( retVal + $? ))


		if [ ! $retVal -eq 0 ]
		then
			echo "There was some error" >> $basedir/{log.stderr}
			exit $retVal
		else
			touch $basedir/{output.ok}
		fi
		
		echo -e "\n$(date)\tFinished!\n"
		"""

rule run_MAKER_PASS2:
	input:
		split_ok = rules.split.output.checkpoint,
		init_ok = rules.initiate_MAKER_PASS2.output.ok
	shadow: "shallow"
	params:
		dir = "{unit}",
		prefix = "{sample}",
		genemark_dir = config["genemark"]["genemark_dir"],
		sub = "results/{sample}/GENOME_PARTITIONS/{unit}.fasta"
	threads: config["threads"]["run_MAKER_PASS2"]
	singularity:
		"docker://chrishah/premaker-plus:18"
	log:
		stdout = "results/{sample}/logs/MAKER.PASS2.run.{sample}.{unit}.stdout.txt",
		stderr = "results/{sample}/logs/MAKER.PASS2.run.{sample}.{unit}.stderr.txt"
	output:
		#sub_fasta = "results/{sample}/MAKER.PASS2/{unit}/{sample}.{unit}.fasta",
		prot_fasta = "results/{sample}/MAKER.PASS2/{unit}/{sample}.{unit}.all.maker.proteins.fasta",
                transcripts_fasta = "results/{sample}/MAKER.PASS2/{unit}/{sample}.{unit}.all.maker.transcripts.fasta",
		gff = "results/{sample}/MAKER.PASS2/{unit}/{sample}.{unit}.all.maker.gff",
		noseq_gff = "results/{sample}/MAKER.PASS2/{unit}/{sample}.{unit}.noseq.maker.gff",
		ok = "checkpoints/{sample}/MAKER.PASS2.{unit}.ok"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"

		basedir=$(pwd)
		export PATH="$(pwd)/bin/maker/bin:$PATH"

		mkdir {params.dir}
		cd {params.dir}
		
		ln -s $basedir/{params.sub} {params.prefix}.{params.dir}.fasta
		
		AUGUSTUS_CONFIG_PATH=$basedir/results/{params.prefix}/MAKER.PASS2/tmp/config
		ln -fs $basedir/{params.genemark_dir}/gm_key .gm_key

		#run MAKER
		maker -base {params.prefix}.{params.dir} -g {params.prefix}.{params.dir}.fasta -nolock -c {threads} $basedir/results/{params.prefix}/MAKER.PASS2/maker_opts.ctl $basedir/results/{params.prefix}/MAKER.PASS2/maker_bopts.ctl $basedir/results/{params.prefix}/MAKER.PASS2/maker_exe.ctl 1> $basedir/{log.stdout} 2> $basedir/{log.stderr}

		#prepare data from MAKER 
		cd {params.prefix}.{params.dir}.maker.output
		gff3_merge -d {params.prefix}.{params.dir}_master_datastore_index.log -o {params.prefix}.{params.dir}.all.maker.gff
		fasta_merge -d {params.prefix}.{params.dir}_master_datastore_index.log
		gff3_merge -n -d {params.prefix}.{params.dir}_master_datastore_index.log -o {params.prefix}.{params.dir}.noseq.maker.gff
		cd ..

		mv {params.prefix}.{params.dir}.maker.output/{params.prefix}.{params.dir}.all.maker.* $basedir/results/{params.prefix}/MAKER.PASS2/{params.dir}
		mv {params.prefix}.{params.dir}.maker.output/{params.prefix}.{params.dir}.noseq.maker.* $basedir/results/{params.prefix}/MAKER.PASS2/{params.dir}
		
		touch $basedir/{output.ok}
		echo -e "\n$(date)\tFinished!\n"
		"""

rule cleanup_MAKER_PASS2:
	input:
		rules.run_MAKER_PASS2.output
	params:
		dir = "{unit}",
		prefix = "{sample}",
		script = "bin/cleanup.sh"
	output:
		gzipped_results = "results/{sample}/MAKER.PASS2/{unit}/{sample}.{unit}.maker.output.tar.gz",
		ok = "checkpoints/{sample}/cleanup_MAKER_PASS2.{unit}.ok"
	singularity:
                "docker://chrishah/premaker-plus:18"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
		basedir=$(pwd)
		
		cd results/{params.prefix}/MAKER.PASS2/{params.dir}/

		bash $basedir/{params.script} {params.prefix}.{params.dir}.maker.output

		touch $basedir/{output.ok}
		echo -e "\n$(date)\tFinished!\n"
		"""	

rule merge_MAKER_PASS2:
	input:
		lambda wildcards: expand("results/{{sample}}/MAKER.PASS2/{unit}/{{sample}}.{unit}.all.maker.gff", sample=wildcards.sample, unit=unitdict[wildcards.sample])
#		expand("results/{unit.sample}/MAKER.PASS2/{unit.unit}/{unit.sample}.{unit.unit}.all.maker.gff", unit=units.itertuples())
	params:
		prefix = "{sample}",
		script = "bin/merging.sh"
	singularity:
		"docker://chrishah/premaker-plus:18"
	output:
		all_gff = "results/{sample}/MAKER.PASS2/{sample}.all.maker.gff",
		noseq_gff = "results/{sample}/MAKER.PASS2/{sample}.noseq.maker.gff",
		proteins = "results/{sample}/MAKER.PASS2/{sample}.all.maker.proteins.fasta",
		ok = "checkpoints/{sample}/merge_MAKER_PASS2.ok"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
		export PATH="$(pwd)/bin/maker/bin:$PATH"
		basedir=$(pwd)
		cd results/{params.prefix}/MAKER.PASS2/

		bash $basedir/{params.script} {params.prefix}

		touch $basedir/{output.ok}
		echo -e "\n$(date)\tFinished!\n"
		"""
