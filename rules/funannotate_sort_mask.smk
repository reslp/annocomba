rule clean:
        input:
                assembly = get_assembly_path

        output:
                "results/{sample}/{sample}_cleaned.fas"
        log:
                "log/{sample}_clean.log"
        params:
                folder = "{sample}",
                minlen = config["clean"]["minlen"]
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
                funannotate clean -i ../../{input.assembly} -o ../../{output} --minlen {params.minlen}  &> ../../{log}
                """

rule sort:
	input:
		assembly = rules.clean.output
	output:
		"results/{sample}/{sample}_sorted.fas"
	log:
		"log/{sample}_sort.log"
	params:
		folder = "{sample}",
		contig_prefix = get_contig_prefix
	threads: 1
	singularity:
		config["containers"]["funannotate"]
	shell:
		"""
		cd results/{params.folder}
		funannotate sort -i ../../{input.assembly} -o ../../{output} -b {params.contig_prefix} &> ../../{log}
		"""

