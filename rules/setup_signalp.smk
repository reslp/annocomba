rule setup_signalp:
	input:
		config["signalp_tarball"]
	output:
		"bin/SignalP/.setup.done"
	params:
		wd = os.getcwd()
	shell:
		"""
		tar xf {input} -C {params.wd}/bin
		# fix weird permissions before copying
		cd {params.wd}/bin/signalp-4.1/syn
		chmod +w {params.wd}/bin/signalp-4.1/syn/*
		#chmod +w {params.wd}/bin/signalp-4.1/syn/*/*
		
		#remove before copying
		rm -rf {params.wd}/bin/SignalP/*

		mv -f {params.wd}/bin/signalp-4.1/* {params.wd}/bin/SignalP
		rm -rf {params.wd}/bin/signalp-4.1
		line=$(grep -n "ENV{{SIGNALP}}" {params.wd}/bin/SignalP/signalp | cut -d ":" -f 1  | head -n 1)
                sed -i "$line s?ENV{{SIGNALP}}.*?ENV{{SIGNALP}} = '$(pwd)/bin/SignalP'?" {params.wd}/bin/SignalP/signalp
                sed -i "s?^my \$outputDir.*?my \$outputDir = '/tmp'?" {params.wd}/bin/SignalP/signalp
		echo "SignalP setup done"
		cd {params.wd}
		touch {output}
		"""
