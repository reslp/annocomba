# This Snakefile containes everything needed for setting up the pipeline. This should be done by running  annocomba --setup.
configfile: "data/config.yaml"

include: "rules/setup_maker.smk"
include: "rules/setup_funannotate.smk"
include: "rules/setup_eggnog.smk"
