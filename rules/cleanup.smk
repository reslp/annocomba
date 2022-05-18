
rule cleanup:
	params:
		prefix = "{sample}",
		wd = os.getcwd()
	threads: 1
	log:
		stdout = "results/{sample}/logs/cleanup.{sample}.stdout.txt",
		stderr = "results/{sample}/logs/cleanup.{sample}.stderr.txt"
	output:
		ok = "results/{sample}/cleanup.done"
	shell:
		"""
		cd results/{wildcards.sample}
		for d in $(ls -hlrt | grep "^d" | awk '{{print $9}}')
		do
			echo -n "compressing $d .. " &> {params.wd}/{log.stdout}
			tar cfz $d.tgz $d &> {params.wd}/{log.stderr}
			if [ $? -eq 0 ]
			then
				rm -rf $d
				echo "Done with $d" &>> {params.wd}/{log.stdout}
			else
				echo "someting wrong with $d" &>> {params.wd}/{log.stdout}
			fi
		done
		touch {params.wd}/{output.ok}
		"""
