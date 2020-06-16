rule repeatmodeler:
	input:
		ok = rules.initiate.output,
		fasta = rules.split.output.fasta
	params:
		prefix = "{sample}",
	threads: config["threads"]["repeatmodeler"]
	singularity:
		"docker://chrishah/premaker-plus:18"
	log:
		stdout = "results/{sample}/logs/REPEATMODELER.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/REPEATMODELER.{sample}.stderr.txt"
	output:
		ok = "results/{sample}/REPEATMODELER/repeatmodeler.status.ok",
		fasta = "results/{sample}/REPEATMODELER/{sample}-families.fa"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"

		if [[ ! -d results/{params.prefix}/REPEATMODELER ]]
		then
			mkdir results/{params.prefix}/REPEATMODELER
		else
			if [ "$(ls -1 results/{params.prefix}/REPEATMODELER/ | wc -l)" -gt 0 ]
			then
				echo -e "Cleaning up remnants of previous run first"
				rm results/{params.prefix}/REPEATMODELER
				mkdir results/{params.prefix}/REPEATMODELER
			fi
		fi
		cd results/{params.prefix}/REPEATMODELER

		#run REPEATMODELER
		BuildDatabase -name {params.prefix} -engine ncbi ../../../{input.fasta} 1> ../../../{log.stdout} 2> ../../../{log.stderr}

		RepeatModeler -pa {threads} -engine ncbi -database {params.prefix} 1>> ../../../{log.stdout} 2>> ../../../{log.stderr}

		retVal=$?

		if [ ! $retVal -eq 0 ]
		then
			echo "REPEATMODELER ended in an error"
			exit $retVal
		else
			touch ../../../{output.ok}
		fi
		echo -e "\n$(date)\tFinished!\n"
		"""

rule cleanup_repeatmodeler:
	input:
		rules.repeatmodeler.output
	params:
		prefix = "{sample}"
	log:
		stdout = "results/{sample}/logs/REPEATMODELER.cleanup.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/REPEATMODELER.cleanup.{sample}.stderr.txt"
	output:
		ok = "results/{sample}/REPEATMODELER/repeatmodeler.cleanup.ok"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
		basedir=$(pwd)
		
		cd results/{params.prefix}/REPEATMODELER
		for f in $(find ./ -type d -name "RM_*")
		do
			echo -e "\nCompressing $f\n"
			tar cfz $f.tar.gz $f
			
			if [ $? -eq 0 ]
			then
        			rm -rf $f
			else
        			echo -e "Some problem with $f"
			fi
		done

		cd $basedir
		touch {output.ok}

		echo -e "\n$(date)\tFinished!\n"

		"""


rule repeatmasker:
	input:
		fasta = rules.split.output.fasta,
		repmod = rules.repeatmodeler.output.fasta
	params:
		prefix = "{sample}",
		repeat_taxon = "eukaryota",
		conversion_script = "bin/convert_repeatmasker_gff_to_MAKER_compatible_gff.sh"
	threads: config["threads"]["repeatmasker"]
	singularity:
		"docker://chrishah/premaker-plus:18"
	log:
		stdout = "results/{sample}/logs/REPEATMASKER.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/REPEATMASKER.{sample}.stderr.txt"
	output:
		ok = "results/{sample}/REPEATMASKER/repeatmasker.status.ok",
		gff = "results/{sample}/REPEATMASKER/{sample}.masked.final.out.reformated.gff",
		masked = "results/{sample}/REPEATMASKER/{sample}.masked.final.fasta"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
		basedir=$(pwd)

		if [[ ! -d results/{params.prefix}/REPEATMASKER ]]
		then
			mkdir results/{params.prefix}/REPEATMASKER
		fi
		cd results/{params.prefix}/REPEATMASKER

		#this is a bit of a hack, but since singularity does not allow to directly write to images ('no space left') and RepeatMasker in the
		#process needs to produce some files, I need to first get the RepeatMasker directory out of the image.
		#Then use the executable in the directory in my writable environment
		#apparently I could also use singularities '--sandbox' option, but from what I can see this would write the content of the entire image to a 
		#directory, so it would take much longer

		#Copy the RepeatMasker directory from the image
		cp -pfr /usr/local/RepeatMasker .

		#Do RepeatMasking with denovo library
		mkdir denovo
		./RepeatMasker/RepeatMasker -engine ncbi -s -pa {threads} -lib $basedir/{input.repmod} -noisy -dir denovo -gff $basedir/{input.fasta} 1> $basedir/{log.stdout} 2> $basedir/{log.stderr}
		retVal=$?

		#run REPEATMASKER against full repeat library, but use only the assembly that is already masked based on the denovo library
		mkdir full
		ln -s $(find ./denovo -name '*fasta.masked') {params.prefix}.masked.denovo.fasta
		./RepeatMasker/RepeatMasker -engine ncbi -s -pa {threads} -species {params.repeat_taxon} -noisy -dir full -gff {params.prefix}.masked.denovo.fasta 1>> $basedir/{log.stdout} 2>> $basedir/{log.stderr}
		retVal=$(( retVal + $? ))

		#cleanup - remove the RepeatMasker directory
		rm -rf RepeatMasker
		rm {params.prefix}.masked.denovo.fasta

		#produce the final repeat annotation
		#copy the final masked fasta and out files from the last Repeatmasker run
		mkdir final
		cd final
		ln -s ../full/{params.prefix}.masked.denovo.fasta.masked {params.prefix}.masked.final.fasta
		ln -s ../full/{params.prefix}.masked.denovo.fasta.out {params.prefix}.masked.final.out

		#produce gff3 file from the final RepeatMasker output (this gff3 seems to work well with MAKER after some conversion - see below)
		/usr/local/RepeatMasker/util/rmOutToGFF3.pl {params.prefix}.masked.final.out > {params.prefix}.masked.final.out.gff3
		retVal=$(( retVal + $? ))

		#modify gff3 file so MAKER accepts it down the line
		$basedir/{params.conversion_script} {params.prefix}.masked.final.out.gff3 > $basedir/{output.gff}

		cd ..
		ln -s final/{params.prefix}.masked.final.fasta $basedir/{output.masked}

		if [ ! $retVal -eq 0 ]
		then
			echo "There was some error"
			exit $retVal
		else
			touch $basedir/{output.ok}
		fi
		echo -e "\n$(date)\tFinished!\n"
		"""
