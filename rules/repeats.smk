rule repeatmodeler:
	input:
		fasta = rules.sort.output.assembly
	params:
		prefix = "{sample}",
	threads: config["threads"]["repeatmodeler"]
	singularity:
		config["containers"]["repeatmodeler"]
	log:
		stdout = "results/{sample}/logs/REPEATMODELER.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/REPEATMODELER.{sample}.stderr.txt"
	output:
		ok = "checkpoints/{sample}/repeatmodeler.status.ok",
		fasta = "results/{sample}/REPEATMODELER/{sample}-families.fa",
		stk = "results/{sample}/REPEATMODELER/{sample}-families.stk"

	shadow: "shallow"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"

		#run REPEATMODELER
		BuildDatabase -name {params.prefix} -engine ncbi {input.fasta} 1> {log.stdout} 2> {log.stderr}

		RepeatModeler -pa $(( {threads} - 1 )) -engine ncbi -database {params.prefix} 1>> {log.stdout} 2>> {log.stderr}

		retVal=$?

		mv {params.prefix}-families.fa {output.fasta}
		mv {params.prefix}-families.stk {output.stk}

		if [ ! $retVal -eq 0 ]
		then
			echo "REPEATMODELER ended in an error"
			exit $retVal
		else
			touch {output.ok}
		fi
		echo -e "\n$(date)\tFinished!\n"
		"""

#rule cleanup_repeatmodeler:
#	input:
#		rules.repeatmodeler.output
#	params:
#		prefix = "{sample}"
#	log:
#		stdout = "results/{sample}/logs/REPEATMODELER.cleanup.{sample}.stdout.txt",
#		stderr = "results/{sample}/logs/REPEATMODELER.cleanup.{sample}.stderr.txt"
#	output:
#		ok = "results/{sample}/REPEATMODELER/repeatmodeler.cleanup.ok"
#	shell:
#		"""
#		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
#		basedir=$(pwd)
#		
#		cd results/{params.prefix}/REPEATMODELER
#		for f in $(find ./ -type d -name "RM_*")
#		do
#			echo -e "\nCompressing $f\n"
#			tar cfz $f.tar.gz $f
#			
#			if [ $? -eq 0 ]
#			then
#      				rm -rf $f
#			else
#       				echo -e "Some problem with $f"
#			fi
#		done
#
#		cd $basedir
#		touch {output.ok}
#
#		echo -e "\n$(date)\tFinished!\n"
#
#		"""

rule repeatmasker_denovo:
	input:
		fasta = rules.sort.output.assembly,
		repmod = rules.repeatmodeler.output.fasta
	params:
		prefix = "{sample}",
		wd = os.getcwd(),
		conversion_script = "bin/convert_repeatmasker_gff_to_MAKER_compatible_gff.sh"
	threads: config["threads"]["repeatmasker"]
	singularity:
		config["containers"]["premaker"]
	log:
		stdout = "results/{sample}/logs/REPEATMASKER-denovo.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/REPEATMASKER-denovo.{sample}.stderr.txt"
	output:
		ok = "checkpoints/{sample}/repeatmasker.denovo.status.ok",
		gff = "results/{sample}/REPEATMASKER/denovo/{sample}.denovo.out.reformated.gff",
		masked = "results/{sample}/REPEATMASKER/denovo/{sample}.denovo.masked.fas"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"

		cd results/{params.prefix}/REPEATMASKER

		#Do RepeatMasking with denovo library
		{params.wd}/bin/RepeatMasker/RepeatMasker -engine ncbi -s -pa $(( {threads} / 4 )) -lib {params.wd}/{input.repmod} -noisy -dir denovo -gff {params.wd}/{input.fasta} -xsmall 1> {params.wd}/{log.stdout} 2> {params.wd}/{log.stderr}
		retVal=$?
		
		cd denovo
		#produce gff3 file from the final RepeatMasker output (this gff3 seems to work well with MAKER after some conversion - see below)
		{params.wd}/bin/RepeatMasker/util/rmOutToGFF3.pl {params.prefix}_sorted.fas.out > {params.prefix}.denovo.out.gff3
		retVal=$(( retVal + $? ))

		#modify gff3 file so MAKER accepts it down the line
		{params.wd}/{params.conversion_script} {params.prefix}.denovo.out.gff3 > {params.wd}/{output.gff}

		# copy masked assembly to base output dir
		ln -s $(pwd)/{params.prefix}_sorted.fas.masked {params.wd}/{output.masked}

		if [ ! $retVal -eq 0 ]
		then
			echo "There was some error"
			exit $retVal
		else
			touch {params.wd}/{output.ok}
		fi
		echo -e "\n$(date)\tFinished!\n"
		
		"""

rule repeatmasker:
	input:
		fasta = rules.sort.output.assembly,
	params:
		prefix = "{sample}",
		repeat_taxon = "eukaryota",
		wd = os.getcwd(),
		conversion_script = "bin/convert_repeatmasker_gff_to_MAKER_compatible_gff.sh"
	threads: config["threads"]["repeatmasker"]
	singularity:
		config["containers"]["premaker"]
	log:
		stdout = "results/{sample}/logs/REPEATMASKER.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/REPEATMASKER.{sample}.stderr.txt"
	output:
		ok = "checkpoints/{sample}/repeatmasker.full.status.ok",
		gff = "results/{sample}/REPEATMASKER/full/{sample}.full.out.reformated.gff",
		masked = "results/{sample}/REPEATMASKER/full/{sample}_masked.fas"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"

		cd results/{params.prefix}/REPEATMASKER

		#run REPEATMASKER against full repeat library, but use only the assembly that is already masked based on the denovo library
		{params.wd}/bin/RepeatMasker/RepeatMasker -engine ncbi -s -pa $(( {threads} / 4 )) -species {params.repeat_taxon} -noisy -dir full -gff {params.wd}/{input.fasta} -xsmall 1> {params.wd}/{log.stdout} 2> {params.wd}/{log.stderr}

		retVal=$?

		cd full
		#produce gff3 file from the final RepeatMasker output (this gff3 seems to work well with MAKER after some conversion - see below)
		{params.wd}/bin/RepeatMasker/util/rmOutToGFF3.pl {params.prefix}_sorted.fas.out > {params.prefix}.full.out.gff3
		retVal=$(( retVal + $? ))

		#modify gff3 file so MAKER accepts it down the line
		{params.wd}/{params.conversion_script} {params.prefix}.full.out.gff3 > {params.wd}/{output.gff}

		# copy masked assembly to base output dir
		ln -s $(pwd)/{params.prefix}_sorted.fas.masked {params.wd}/{output.masked}

		if [ ! $retVal -eq 0 ]
		then
			echo "There was some error"
			exit $retVal
		else
			touch {params.wd}/{output.ok}
		fi
		echo -e "\n$(date)\tFinished!\n"
		"""

rule mask_repeats:
	input:
		fasta = rules.sort.output.assembly,
		denovo_gff = rules.repeatmasker_denovo.output.gff,
		full_gff = rules.repeatmasker.output.gff
	params:
		prefix = "{sample}",
		wd = os.getcwd(),
		script = "bin/mask_fasta.py"
	threads: 1
	singularity:
		config["containers"]["funannotate"]
	log:
		stdout = "results/{sample}/logs/REPEATMASK.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/REPEATMASK.{sample}.stderr.txt"
	output:
		ok = "checkpoints/{sample}/repeatmasking.status.ok",
		soft = "results/{sample}/REPEATMASKER/{sample}_sorted.softmasked.fas",
		hard = "results/{sample}/REPEATMASKER/{sample}_sorted.hardmasked.fas"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"

		cd results/{params.prefix}/REPEATMASKER

		cat $(find ./ -name "*.reformated.gff") > all.gff
		retVal=$?
		{params.wd}/{params.script} {params.wd}/{input.fasta} all.gff soft > {params.wd}/{output.soft}
		retVal=$(( retVal + $? ))
		{params.wd}/{params.script} {params.wd}/{input.fasta} all.gff hard > {params.wd}/{output.hard}
		retVal=$(( retVal + $? ))
		rm all.gff

		if [ ! $retVal -eq 0 ]
		then
			echo "There was some error"
			exit $retVal
		else
			touch {params.wd}/{output.ok}
		fi
		echo -e "\n$(date)\tFinished!\n"
		"""

#rule repeatmasker:
#	input:
#		fasta = rules.sort.output.assembly,
#		repmod = rules.repeatmodeler.output.fasta
#	params:
#		prefix = "{sample}",
#		repeat_taxon = "eukaryota",
#		wd = os.getcwd(),
#		conversion_script = "bin/convert_repeatmasker_gff_to_MAKER_compatible_gff.sh"
#	threads: config["threads"]["repeatmasker"]
#	singularity:
#		config["containers"]["premaker"]
#	log:
#		stdout = "results/{sample}/logs/REPEATMASKER.{sample}.stdout.txt",
#		stderr = "results/{sample}/logs/REPEATMASKER.{sample}.stderr.txt"
#	output:
#		ok = "checkpoints/{sample}/repeatmasker.status.ok",
#		gff = "results/{sample}/REPEATMASKER/{sample}.masked.final.out.reformated.gff",
#		masked = "results/{sample}/{sample}_masked.fas"
#	shell:
#		"""
#		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
#		basedir=$(pwd)
#
#		if [[ -d results/{params.prefix}/REPEATMASKER ]]
#		then
#			rm -r results/{params.prefix}/REPEATMASKER
#		fi
#		mkdir results/{params.prefix}/REPEATMASKER
#		cd results/{params.prefix}/REPEATMASKER
#
#		#this is a bit of a hack, but since singularity does not allow to directly write to images ('no space left') and RepeatMasker in the
#		#process needs to produce some files, I need to first get the RepeatMasker directory out of the image.
#		#Then use the executable in the directory in my writable environment
#		#apparently I could also use singularities '--sandbox' option, but from what I can see this would write the content of the entire image to a 
#		#directory, so it would take much longer
#
#		#Copy the RepeatMasker directory from the image
#		#cp -pfr /usr/local/RepeatMasker .
#
#		#Do RepeatMasking with denovo library
#		mkdir denovo
#		{params.wd}/bin/RepeatMasker -engine ncbi -s -pa $(( {threads} / 4 )) -lib $basedir/{input.repmod} -noisy -dir denovo -gff $basedir/{input.fasta} -xsmall 1> $basedir/{log.stdout} 2> $basedir/{log.stderr}
#		retVal=$?
#
#		#run REPEATMASKER against full repeat library, but use only the assembly that is already masked based on the denovo library
#		mkdir full
#		ln -s $(find ./denovo -name '*fas.masked') {params.prefix}.masked.denovo.fasta
#		{params.wd}/bin/RepeatMasker -engine ncbi -s -pa $(( {threads} / 4 )) -species {params.repeat_taxon} -noisy -dir full -gff {params.prefix}.masked.denovo.fasta -xsmall 1>> $basedir/{log.stdout} 2>> $basedir/{log.stderr}
#
#		retVal=$(( retVal + $? ))
#
#		#cleanup - remove the RepeatMasker directory
#		#rm -rf RepeatMasker
#		rm {params.prefix}.masked.denovo.fasta
#
#		#produce the final repeat annotation
#		#copy the final masked fasta and out files from the last Repeatmasker run
#		mkdir final
#		cd final
#		ln -s ../full/{params.prefix}.masked.denovo.fasta.masked {params.prefix}.masked.final.fasta
#		ln -s ../full/{params.prefix}.masked.denovo.fasta.out {params.prefix}.masked.final.out
#
#		#produce gff3 file from the final RepeatMasker output (this gff3 seems to work well with MAKER after some conversion - see below)
#		/usr/local/RepeatMasker/util/rmOutToGFF3.pl {params.prefix}.masked.final.out > {params.prefix}.masked.final.out.gff3
#		retVal=$(( retVal + $? ))
#
#		#modify gff3 file so MAKER accepts it down the line
#		$basedir/{params.conversion_script} {params.prefix}.masked.final.out.gff3 > $basedir/{output.gff}
#
#		# copy masked assembly to base output dir
#		cd ..
#		cp final/{params.prefix}.masked.final.fasta $basedir/{output.masked}
#
#		if [ ! $retVal -eq 0 ]
#		then
#			echo "There was some error"
#			exit $retVal
#		else
#			touch $basedir/{output.ok}
#		fi
#		echo -e "\n$(date)\tFinished!\n"
#		"""
#
