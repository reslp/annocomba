rule setup_genemark:
	input:
		genemark = config["genemark_tarball"],
		keyfile = config["genemark_keyfile"]
	output:
		"bin/Genemark/.setup.done"
	params:
		wd = os.getcwd()
	shell:
		"""
		#this extracts the name of the directory that will be created when unpacking
		#for some reason this always returns the error code 141 (at least in my tests) so I'll catch the error code
		dirname=$(tar tvf {params.wd}/{input.genemark} | head -1 | awk '{{print $6}}') && returncode=$? || returncode=$?

		#unpack
		tar xf {input.genemark} -C {params.wd}/bin
		#cleanup in case there are remnants of a previous attempt
		if [[ -d {params.wd}/bin/Genemark ]]; then rm -rf {params.wd}/bin/Genemark; fi
		#move to defined place
		mv -f {params.wd}/bin/$dirname {params.wd}/bin/Genemark
		#gunzip and move keyfile to correct place
		gunzip -c {input.keyfile} > {params.wd}/bin/Genemark/gm_key 
		#finalise
		touch {output}
		echo "GeneMark setup complete"
		"""
