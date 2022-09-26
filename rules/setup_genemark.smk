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
		tar xf {input.genemark} -C {params.wd}/bin
		rm -rf {params.wd}/bin/Genemark/*
		mv -f {params.wd}/bin/gmes_linux_64/* {params.wd}/bin/Genemark/
		rm -rf {params.wd}/bin/gmes_linux_64
		gunzip -c {input.keyfile} > {params.wd}/bin/Genemark/gm_key 
		touch {output}
		echo "GeneMark setup complete"
		"""
