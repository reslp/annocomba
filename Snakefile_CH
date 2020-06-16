configfile: "data/config.yaml"

localrules: initiate, all

include: "rules/setup_maker.smk"
include: "rules/functions.smk"
include: "rules/maker_part_one.smk"
include: "rules/repeats.smk"
include: "rules/maker_post_repeats.smk"

rule all:
	input:
		expand("results/{unit.sample}/MAKER.PASS1/{unit.unit}/{unit.sample}.{unit.unit}.maker.output.tar.gz", unit=units.itertuples()),
		expand("results/{unit.sample}/MAKER.PASS2/{unit.unit}/{unit.sample}.{unit.unit}.maker.output.tar.gz", unit=units.itertuples()),
		expand("results/{name}/REPEATMODELER/repeatmodeler.cleanup.ok", name=samples.index.tolist()),
		expand("results/{name}/MAKER.PASS2/{name}.all.maker.gff", name=samples.index.tolist())

