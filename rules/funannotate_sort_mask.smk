if config["clean"]["run"]:
        rule clean:
                input:
                        assembly = get_assembly_path

                output:
                        assembly ="results/{sample}/{sample}_cleaned.fas",
		        ok = "checkpoints/{sample}/clean.ok"
                log:
                        "log/{sample}_clean.log"
                params:
                        folder = "{sample}",
                        minlen = config["clean"]["minlen"],
	        	wd = os.getcwd()
        	threads: 1
                singularity:
        		config["containers"]["funannotate"]
        	shell:
                        """
        		cd results/{params.folder}
                        funannotate clean -i {input.assembly} -o {params.wd}/{output.assembly} --minlen {params.minlen} &> {params.wd}/{log}
        		touch {output.ok}
        		"""

        rule sort:
        	input:
        		assembly = rules.clean.output.assembly
        	output:
        		assembly = "results/{sample}/{sample}_sorted.fas",
        		ok = "checkpoints/{sample}/sort.ok"
        	log:
        		"log/{sample}_sort.log"
        	params:
        		folder = "{sample}",
        		contig_prefix = get_contig_prefix,
        		wd = os.getcwd()
        	threads: 1
        	singularity:
        		config["containers"]["funannotate"]
        	shell:
        		"""
        		cd results/{params.folder}
        		funannotate sort -i {input.assembly} -o {params.wd}/{output.assembly} -b {params.contig_prefix} &> {params.wd}/{log}
        		touch {params.wd}/{output.ok}
        		"""
else:
        rule sort:
        	input:
        		assembly = get_assembly_path
        	output:
        		assembly = "results/{sample}/{sample}_sorted.fas",
        		ok = "checkpoints/{sample}/sort.ok"
        	log:
        		"log/{sample}_sort.log"
        	params:
        		folder = "{sample}",
        		contig_prefix = get_contig_prefix,
        		wd = os.getcwd(),
                        minlen = config["clean"]["minlen"],
			script = "bin/lengthfilter.py"
        	threads: 1
        	singularity:
        		config["containers"]["funannotate"]
        	shell:
        		"""
        		cd results/{params.folder}
                        funannotate sort -i {input.assembly} -o {params.folder}_sorted.all.fasta -b {params.contig_prefix} &> {params.wd}/{log}
        		{params.wd}/{params.script} {params.folder}_sorted.all.fasta {params.minlen} > {params.wd}/{output.assembly}
        		touch {params.wd}/{output.ok}
        		"""
