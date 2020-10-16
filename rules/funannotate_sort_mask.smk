if config["clean"]["run"]:
        rule clean:
                input:
                        assembly = get_assembly_path

                output:
                        assembly ="results/{sample}/{sample}_cleaned.fas",
		        ok = "checkpoints/{sample}/clean.ok"
                log:
                        "results/{sample}/logs/clean.{sample}.log"
                params:
                        folder = "{sample}",
                        minlen = config["clean"]["minlen"],
	        	wd = os.getcwd()
        	threads: 1
                singularity:
        		config["containers"]["funannotate"]
        	shell:
                        """
                        funannotate clean -i {input.assembly} -o {output.assembly} --minlen {params.minlen} &> {log}
        		touch {output.ok}
        		"""

        rule sort:
        	input:
        		assembly = rules.clean.output.assembly
        	output:
        		assembly = "results/{sample}/{sample}_sorted.fas",
        		ok = "checkpoints/{sample}/sort.ok"
        	log:
        		"results/{sample}/logs/sort.{sample}.log"
        	params:
        		folder = "{sample}",
        		contig_prefix = get_contig_prefix,
        		wd = os.getcwd()
        	threads: 1
        	singularity:
        		config["containers"]["funannotate"]
        	shell:
        		"""
        		funannotate sort -i {input.assembly} -o {output.assembly} -b {params.contig_prefix} &> {log}
        		touch {output.ok}
        		"""
else:
        rule sort:
        	input:
        		assembly = get_assembly_path
        	output:
        		full_assembly = "results/{sample}/{sample}_sorted.all.fas",
			assembly = "results/{sample}/{sample}_sorted.fas",
        		ok = "checkpoints/{sample}/sort.ok"
        	log:
        		"results/{sample}/logs/clean.{sample}.log"
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
                        funannotate sort -i {input.assembly} -o {output.full_assembly} -b {params.contig_prefix} &> {log}
        		{params.script} {output.full_assembly} {params.minlen} > {output.assembly}
        		touch {output.ok}
        		"""
