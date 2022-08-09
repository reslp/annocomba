# This Snakefile containes everything needed for setting up the pipeline. This should be done by running  annocomba --setup.
configfile: "data/config.yaml"

include: "setup_maker.smk"
include: "setup_funannotate.smk"
include: "setup_eggnog.smk"
