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
                if [[ ! -d results/{params.folder} ]]
                then
                        mkdir results/{params.folder}
                fi
                cd results/{params.folder}
                funannotate clean -i ../../{input.assembly} -o ../../{output.assembly} --minlen {params.minlen}  &> ../../{log}
                cd {params.wd}
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
		funannotate sort -i ../../{input.assembly} -o ../../{output.assembly} -b {params.contig_prefix} &> ../../{log}
		cd {params.wd}
		touch {output.ok}
		"""

