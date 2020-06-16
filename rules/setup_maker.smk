
rule setup_maker:
	input:
		maker_tarball = config["maker_tarball"],
	params:
		repbase = config["RepbaseRepeatMaskerEdition"]
	singularity:
		"docker://chrishah/premaker-plus:18"
	output: 
		bin = directory("bin/maker/bin")
	shell:
		"""
		echo -e "\n$(date)\tStarting on host: $(hostname) ...\n"
		basedir=$(pwd)

		#Copy the RepeatMasker directory from the image
		cp -pfrv /usr/local/RepeatMasker bin/

		if [ "{params.repbase}" == "None" ]
		then
			echo -e "No additional Repeatlibrary provided - ok"
		else
			bin/setup_Repeatmasker.sh bin/ {params.repbase}
#			tar xvfz {params.repbase} -C bin/RepeatMasker/
#			perl bin/RepeatMasker/rebuild
		fi

		if [ "{input.maker_tarball}" == "None" ]
		then
			echo -e "Providing a maker tarball is mandatory"
			exit 1
		else
			bash bin/setup_maker.sh {input.maker_tarball} bin 
		fi
	"""
