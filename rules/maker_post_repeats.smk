from os import path

rule prepare_protein_evidence:
	input:
		proteins = expand("{full}/{file}", full=[os.getcwd()], file=glob.glob(config["protein_evidence_path"]+"/*.gz")),
	params:
		prefix = "{sample}",
		mem = "8000",
		similarity = config["cdhit"]["similarity"],
		wd = os.getcwd()
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
		cat <(gzip -c {params.wd}/data/funannotate_database/uniprot_sprot.fasta) {input.proteins} > external_proteins.fasta.gz

		#run cd-hit
		cd-hit -T {threads} -M {params.mem} -i external_proteins.fasta.gz -o external_proteins.cd-hit-{params.similarity}.fasta -c {params.similarity} 1> ../../../{log.stdout} 2> ../../../{log.stderr}
		retVal=$?

		# remove spaces at the end of any lines (this is sometimes the case and throws off some software)
		sed -i s/ $//' external_proteins.cd-hit-{params.similarity}.fasta
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
def trigger_repeatmasking(wildcards):
	if sample_data.loc[wildcards.sample, ["premasked"]].to_list()[-1] == "yes":
		return "results/"+wildcards.sample+"/ASSEMBLY_CLEANUP/"+wildcards.sample+"_sorted.fas"
	else:
		return "results/"+wildcards.sample+"/REPEATMASKER/"+wildcards.sample+"_sorted.softmasked.fas"


if path.exists("bin/Genemark/gm_key"):
	rule genemark:
		input:
			fasta = trigger_repeatmasking
		params:
			prefix = "{sample}",
			genemark_dir = "bin/Genemark",
			gmes_petap_params = config["genemark"]["gmes_petap_params"],
			wd = os.getcwd()
		threads: config["threads"]["genemark"]
		singularity: config["containers"]["braker"]
		log:
			stdout = "results/{sample}/logs/GENEMARK.{sample}.stdout.txt",
			stderr = "results/{sample}/logs/GENEMARK.{sample}.stderr.txt"
		output:
			check = "checkpoints/{sample}/genemark.status.ok",
		shell:
			"""
			echo -e "\\n$(date)\tStarting on host: $(hostname) ...\\n"
			#export PATH="{params.wd}/{params.genemark_dir}:$PATH"

			export GENEMARK_PATH="/opt/ETP/bin/gmes"
                
			if [[ ! -d results/{params.prefix}/GENEMARK ]]
			then
				mkdir results/{params.prefix}/GENEMARK
			else
				if [ "$(ls -1 results/{params.prefix}/GENEMARK/ | wc -l)" -gt 0 ]
				then
				echo -e "\\n$(date)\tCleaning up remnants of previous run first" 1> {log.stdout} 2> {log.stderr}
					rm -rf results/{params.prefix}/GENEMARK
					mkdir results/{params.prefix}/GENEMARK
				fi
			fi
			cd results/{params.prefix}/GENEMARK

			# can this be done as part of setup? perhaps not, since this place does not yet exist on setup
			#ln -sf {params.wd}/{params.genemark_dir}/gm_key .gm_key

			if [ "{params.gmes_petap_params}" == "None" ]
			then
				gmes_petap.pl --ES --cores {threads} -sequence {params.wd}/{input.fasta} --soft_mask auto 1>> {params.wd}/{log.stdout} 2>> {params.wd}/{log.stderr}
			else
				gmes_petap.pl --ES {params.gmes_petap_params} --cores {threads} -sequence {params.wd}/{input.fasta} --soft_mask auto 1>> {params.wd}/{log.stdout} 2>> {params.wd}/{log.stderr}
			fi

			# tar genemark output to save space and reduce number of files:
			tar -cfz output.tar.gz -C $(pwd) output
			rm -rf output
			tar -cfz data.tar.gz -C $(pwd) data
			rm -rf data
			tar -cfz run.tar.gz -C $(pwd) run
			rm -rf run

			touch {params.wd}/{output.check}
			echo -e "\\n$(date)\tFinished!\\n"
		
			"""		
else:
	rule genemark:
		log:
			stdout = "results/{sample}/logs/GENEMARK.{sample}.stdout.txt",
			stderr = "results/{sample}/logs/GENEMARK.{sample}.stderr.txt"
		output:
			check = "checkpoints/{sample}/genemark.status.skipped",
		shell:
			"""
			touch {output.check}
			"""
def trigger_repeatmodeler(wildcards):
	if sample_data.loc[wildcards.sample, ["premasked"]].to_list()[-1] == "yes":
		return []
	else:
		return "results/"+wildcards.sample+"/REPEATMODELER/"+wildcards.sample+"-families.fa"
def trigger_repeatmasker_denovo(wildcards):
	if sample_data.loc[wildcards.sample, ["premasked"]].to_list()[-1] == "yes":
		return []
	else:
		return "results/"+wildcards.sample+"/REPEATMASKER/denovo/"+wildcards.sample+".denovo.out.reformated.gff"
def trigger_repeatmasker_full(wildcards):
	if sample_data.loc[wildcards.sample, ["premasked"]].to_list()[-1] == "yes":
		return []
	else:
		return "results/"+wildcards.sample+"/REPEATMASKER/full/"+wildcards.sample+".full.out.reformated.gff"
def trigger_busco(wildcards):
	if config["skip_BUSCO"] == "yes":
		return []
	else:
		#this triggers busco
		return "results/"+wildcards.sample+"/BUSCO/"+wildcards.sample+".BUSCOs.fasta"
def trigger_cdhit(wildcards):
	if config["protein_evidence_path"] == "skip":
		return []
	else:
		#this triggers cdhit
		return "results/"+wildcards.sample+"/NR_PROTEIN_EVIDENCE/nr_external_proteins.cd-hit.fasta"

rule initiate_MAKER_PASS1:
	input:
		ok = rules.split.output.checkpoint,
		snap = rules.snap_pass1.output.hmm,
		nr_evidence = trigger_cdhit,
		busco_proteins = trigger_busco,
		repmod_lib = trigger_repeatmodeler,
		repmas_gff_denovo = trigger_repeatmasker_denovo,
		repmas_gff = trigger_repeatmasker_full
	params:
		prefix = "{sample}",
		transcripts = get_transcripts_path,
		script = "bin/prepare_maker_opts_PASS1.sh"
	singularity:
		config["containers"]["premaker"]
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


		if [[ -d results/{params.prefix}/MAKER.PASS1 ]]
		then
			rm -rf results/{params.prefix}/MAKER.PASS1
		fi
		mkdir results/{params.prefix}/MAKER.PASS1
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
		sub = "results/{sample}/GENOME_PARTITIONS/{unit}.fasta",
		extra_params = config['maker']['maker_pass_1_options'] 
	threads: config["threads"]["run_MAKER_PASS1"]
	shadow: "shallow"
	singularity:
		config["containers"]["premaker"]
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
		maker -base {params.prefix}.{params.dir} -g {params.prefix}.{params.dir}.fasta -nolock $(if [[ "{params.extra_params}" != "None" ]]; then echo "{params.extra_params}"; fi) -c $(( {threads} - 1 )) $basedir/results/{params.prefix}/MAKER.PASS1/maker_opts.ctl $basedir/results/{params.prefix}/MAKER.PASS1/maker_bopts.ctl $basedir/results/{params.prefix}/MAKER.PASS1/maker_exe.ctl 1> $basedir/{log.stdout} 2> $basedir/{log.stderr}

		#prepare data from MAKER 
		echo "\nMAKER is done - merging output files" 1>> $basedir/{log.stdout}
		cd {params.prefix}.{params.dir}.maker.output
		gff3_merge -d {params.prefix}.{params.dir}_master_datastore_index.log -o {params.prefix}.{params.dir}.all.maker.gff
		fasta_merge -d {params.prefix}.{params.dir}_master_datastore_index.log
		gff3_merge -n -d {params.prefix}.{params.dir}_master_datastore_index.log -o {params.prefix}.{params.dir}.noseq.maker.gff

		echo "This is what MAKER has produced:" 1>> $basedir/{log.stdout}
		ls -hlrt 1>> $basedir/{log.stdout}

		echo "Moving things over" 1>> $basedir/{log.stdout}
		mv -v {params.prefix}.{params.dir}.all.maker.* $basedir/results/{params.prefix}/MAKER.PASS1/{params.dir} 1>> $basedir/{log.stdout} 2>> $basedir/{log.stderr}
		mv -v {params.prefix}.{params.dir}.noseq.maker.* $basedir/results/{params.prefix}/MAKER.PASS1/{params.dir} 1>> $basedir/{log.stdout} 2>> $basedir/{log.stderr}

		if [[ ! -f $basedir/{output.transcripts_fasta} ]]
		then
			echo "touching {params.prefix}.{params.dir}.all.maker.transcripts.fasta" 1>> $basedir/{log.stdout}
			touch $basedir/{output.transcripts_fasta}
		fi
		if [[ ! -f $basedir/{output.prot_fasta} ]]
		then
			echo "touching {params.prefix}.{params.dir}.all.maker.proteins.fasta" 1>> $basedir/{log.stdout}
			touch $basedir/{output.prot_fasta}
		fi

		touch $basedir/{output.ok}	
		echo -e "\n$(date)\tFinished!\n"
		"""

#rule cleanup_MAKER_PASS1:
#	input:
#		rules.merge_MAKER_PASS1.ok
#	params:
#		prefix = "{sample}",
#		script = "bin/cleanup.sh"
#	singularity:
#		config["containers"]["premaker"]
#	output:
#		ok = "results/{sample}/MAKER.PASS1/cleanup.done"
#	shell:
#		"""
#		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
#		basedir=$(pwd)
#		
#		cd results/{params.prefix}/MAKER.PASS1/
#
#		#clean up some
#		echo -e "\n\n[$(date)]\tCleaning up:" >> {params.wd}/{log}
#		for d in $(find ./ -maxdepth 1 -mindepth 1 -type d)
#		do
#			bash $basedir/{params.script} $d
#		done 
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
		config["containers"]["premaker"]
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

def specify_training_params(wildcards):
	if config["skip_BUSCO"] == "yes":
		if config["augustus_training_params"]:
			return config["augustus_training_params"]
		else:
			return "from_scratch"
	else:
		return "results/"+wildcards.sample+"/BUSCO/"+wildcards.sample+"/run_"+config["busco_set"]+"/augustus_output/retraining_parameters/BUSCO_"+wildcards.sample

rule AUGUSTUS_PASS2:
	input:
		busco_ok = trigger_busco,
		fasta = trigger_repeatmasking,
		maker_proteins = rules.merge_MAKER_PASS1.output.proteins
	params:
		prefix = "{sample}",
		training_params = specify_training_params,
		script = "bin/augustus.PASS2.sh",
		aed = "{aed}",
		transcripts = get_transcripts_path, 
		extra_params = config['augustus']['train_augustus_options'] 
	threads: config["threads"]["AUGUSTUS_PASS2"]
	singularity:
		config["containers"]["augustus"]
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

		if [[ -d tmp.{params.aed} ]]
		then
			rm -rf tmp.{params.aed}
		fi
		
		#copy augustus config directory from the image
		mkdir tmp.{params.aed}
		cp -rf /usr/share/augustus/config tmp.{params.aed}/config

		est="{params.transcripts[ests]}"
		if [ ! -z "$est" ]
		then
			cat $est > cdna.{params.aed}.fasta	
		fi

		if [[ "{params.training_params}" == "from_scratch" ]]
		then
			training_params="from_scratch"
		else
			training_params="$basedir/{params.training_params}"
		fi

		bash $basedir/{params.script} \
		{threads} \
		{params.aed}.{params.prefix} \
		$basedir/{input.fasta} \
		$basedir/{input.maker_proteins} \
		{params.aed} \
		$(pwd)/tmp.{params.aed}/config \
		$training_params \
		cdna.{params.aed}.fasta \
		'{params.extra_params}' \
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
			rm -rf tmp.{params.aed}
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
		config["containers"]["augustus"]
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"

		echo -e "{input}" 
		echo -e "{params.aeds}"
		
		for aed in $(echo -e "{params.aeds}")
		do
			echo -e "$aed\t$(grep "accuracy after optimizing" results/{params.prefix}/logs/AUGUSTUS.PASS2.$aed.{params.prefix}.stdout.txt | rev | cut -d " " -f 1 | rev)"
		done > results/{params.prefix}/AUGUSTUS.PASS2/summary.tsv

		best=$(cat results/{params.prefix}/AUGUSTUS.PASS2/summary.tsv | perl -ne 'chomp; ($aed,$acc)=split("\t"); if ($acc > $best){{$winner = $aed; $best = $acc}}; if (eof()){{print "$winner\n"}}')
		echo "{params.prefix}: Best training accuracy was achieved with cutoff $best"

		if [ -d {params.best_params} ]; then rm {params.best_params}; fi
		ln -sf $(pwd)/results/{params.prefix}/AUGUSTUS.PASS2/$best/$best.{params.prefix} {params.best_params}
		
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
		config["containers"]["premaker"]
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

def trigger_genemark(wildcards):
	if config["genemark"]["skip"] == "yes":
		return []
	else:
		return "checkpoints/"+wildcards.sample+"/genemark.status.ok"

rule initiate_MAKER_PASS2:
	input:
		snaphmm = rules.snap_pass2.output.snap_hmm,
		MP1_ok = rules.merge_MAKER_PASS1.output,
		genemark = trigger_genemark
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
		config["containers"]["premaker"]
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

		if [[ -d results/{params.prefix}/MAKER.PASS2 ]]
		then
			rm -rf results/{params.prefix}/MAKER.PASS2
		fi
		mkdir results/{params.prefix}/MAKER.PASS2
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
		$(if [ -f "$basedir/{input.genemark}" ]; then echo "$basedir/results/{params.prefix}/GENEMARK/gmhmm.mod"; else echo "none"; fi) \
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
		init_ok = rules.initiate_MAKER_PASS2.output.ok
	shadow: "shallow"
	params:
		dir = "{unit}",
		prefix = "{sample}",
		genemark_dir = "bin/Genemark",
		sub = "results/{sample}/GENOME_PARTITIONS/{unit}.fasta",
		extra_params = config['maker']['maker_pass_2_options'] 
	threads: config["threads"]["run_MAKER_PASS2"]
	singularity:
		config["containers"]["premaker"]
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
		if [ -s "$basedir/{params.genemark_dir}" ]; then 
			ln -fs $basedir/{params.genemark_dir}/gm_key .gm_key;
		fi

		#run MAKER
		maker -base {params.prefix}.{params.dir} -g {params.prefix}.{params.dir}.fasta -nolock $(if [[ "{params.extra_params}" != "None" ]]; then echo "{params.extra_params}"; fi) -c {threads} $basedir/results/{params.prefix}/MAKER.PASS2/maker_opts.ctl $basedir/results/{params.prefix}/MAKER.PASS2/maker_bopts.ctl $basedir/results/{params.prefix}/MAKER.PASS2/maker_exe.ctl 1> $basedir/{log.stdout} 2> $basedir/{log.stderr}

		#prepare data from MAKER 
		echo "\nMAKER is done - merging output files" 1>> $basedir/{log.stdout}
		cd {params.prefix}.{params.dir}.maker.output
		gff3_merge -d {params.prefix}.{params.dir}_master_datastore_index.log -o {params.prefix}.{params.dir}.all.maker.gff
		fasta_merge -d {params.prefix}.{params.dir}_master_datastore_index.log
		gff3_merge -n -d {params.prefix}.{params.dir}_master_datastore_index.log -o {params.prefix}.{params.dir}.noseq.maker.gff
		
		echo "This is what MAKER has produced:" 1>> $basedir/{log.stdout}
		ls -hlrt 1>> $basedir/{log.stdout}
		cd ..

		echo "Moving things over" 1>> $basedir/{log.stdout}
		mv -v {params.prefix}.{params.dir}.maker.output/{params.prefix}.{params.dir}.all.maker.* $basedir/results/{params.prefix}/MAKER.PASS2/{params.dir} 1>> $basedir/{log.stdout} 2>> $basedir/{log.stderr}
		mv -v {params.prefix}.{params.dir}.maker.output/{params.prefix}.{params.dir}.noseq.maker.* $basedir/results/{params.prefix}/MAKER.PASS2/{params.dir} 1>> $basedir/{log.stdout} 2>> $basedir/{log.stderr}
	
		if [[ ! -f $basedir/{output.transcripts_fasta} ]]
		then
			echo "touching {params.prefix}.{params.dir}.all.maker.transcripts.fasta" 1>> $basedir/{log.stdout}
			touch $basedir/{output.transcripts_fasta}
		fi
		if [[ ! -f $basedir/{output.prot_fasta} ]]
		then
			echo "touching {params.prefix}.{params.dir}.all.maker.proteins.fasta" 1>> $basedir/{log.stdout}
			touch $basedir/{output.prot_fasta}
		fi
		
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
		config["containers"]["premaker"]
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
		config["containers"]["premaker"]
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
		basedir=$(pwd)
		
		cd results/{params.prefix}/MAKER.PASS2/{params.dir}/

		bash $basedir/{params.script} {params.prefix}.{params.dir}.maker.output

		touch $basedir/{output.ok}
		echo -e "\n$(date)\tFinished!\n"
		"""	


