
rule setup_maker:
	input:
		maker_tarball = config["maker_tarball"],
	params:
		repbase = config["RepbaseRepeatMaskerEdition"]
	singularity:
		config["containers"]["premaker"]
	output: 
		bin = directory("bin/maker/bin"),
		repeatmasker_ok = "bin/RepeatMasker/repeatmasker.ok"
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
		basedir=$(pwd)

		if [ "{params.repbase}" == "None" ]
		then
			echo -e "No Repbase Repeatmasker library provided - ok"
		else
			echo -e "Repbase Repatmasker library provided: {params.repbase} - ok"
		fi
		echo -e "Setting up RepeatMasker in '$(pwd)/bin/RepeatMasker/'"
		bin/setup_Repeatmasker.sh bin/ {params.repbase}
		touch {output.repeatmasker_ok}

		if [ "{input.maker_tarball}" == "None" ]
		then
			echo -e "Providing a maker tarball is mandatory"
			exit 1
		else
			echo -e "\nSetting up maker in '$(pwd)/bin/maker/'"
			bash bin/setup_maker.sh {input.maker_tarball} bin 
		fi
	"""
