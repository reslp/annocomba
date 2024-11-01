# This Snakefile containes everything needed for setting up the pipeline. This should be done by running  annocomba --setup.

include: "setup_maker.smk"
include: "setup_funannotate.smk"
include: "setup_eggnog.smk"
include: "setup_genemark.smk"
include: "setup_signalp.smk"
include: "setup_ncbicheck.smk"
