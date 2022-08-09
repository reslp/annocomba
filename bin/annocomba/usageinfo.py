#some basic variables needed:
try:
	with open(".version", "r") as file:
		version = file.readline().strip("\n")
except FileNotFoundError:
	version = "unkown"

annocomba = """
			     Welcome to annocomba v%s
""" % version

default_help = annocomba +  """
Usage: annocomba <command> <arguments>
Commands:
	setup			Setup pipeline
	annotate-full		Create genome annotations using MAKER and funannotate
	annotate-maker		Create genome annotations using MAKER
	annotate-funannotate	Create genome annotatations using funannotate
	-v, --version 		Print version
	-h, --help		Display help
Examples:
	To see options for the setup step:
	./annocomba setup -h

"""

standard_arguments= """Argumemts:
	-t, --cluster		Specify cluster type. Options: slurm, sge, torque, local. Default: local (no job submission)
	-c, --cluster-config	Specify Cluster config file path. Default: data/cluster-config-CLUSTERTYPE.yaml.template
	-f, --force		Soft force runmode which has already been run.
	-F, --FORCE		Hard force runmode recreating all output.
	
	--dry			Make a dry run.
	--verbose		Display more output.
	-h, --help		Display help.
"""


setup_help = """
Usage: annocomba setup
Arguments:
	--maker			Will setup MAKER and all dependencies
	--funannotate		Will setup Funannotate and download all databases
	--eggnog		Will setup Eggnog DB
	--all			Will do all of the above

Additional """ + standard_arguments 
