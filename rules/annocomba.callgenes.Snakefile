include: "utilities.smk"

rule maker_all:
	input:
#		expand("results/{name}/{name}_sorted.fas", name=get_sample_selection()),
                expand("checkpoints/{name}/split.ok", name=get_sample_selection()),
		expand("checkpoints/{name}/busco.status.ok", name=get_sample_selection()),
                expand("checkpoints/{name}/cegma.status.ok", name=get_sample_selection()),
                expand("checkpoints/{name}/repeatmodeler.status.ok", name=get_sample_selection()),
                expand("checkpoints/{name}/repeatmasker.denovo.status.ok", name=get_sample_selection()),
                expand("checkpoints/{name}/repeatmasker.full.status.ok", name=get_sample_selection()),
                expand("checkpoints/{name}/MAKER_PASS1_init.ok", name=get_sample_selection()),
		expand("checkpoints/{name}/merge_MAKER_PASS1.ok", name=get_sample_selection()),
                expand("checkpoints/{name}/MAKER.PASS2.init.ok", name=get_sample_selection()),
                expand("results/{name}/MAKER.PASS2/{name}.all.maker.gff", name=get_sample_selection()),

rule funannotate_predict_all:
	input:
		expand("checkpoints/{name}/FUNANNOTATE_tarpredict.done", name=get_sample_selection())
		

include: "assembly_cleanup.smk"
include: "maker_part_one.smk"
include: "repeats.smk"
include: "maker_post_repeats.smk"
include: "funannotate_predict.smk"

