#!/usr/bin/env python3

import sys, os, io
sys.path.insert(0, os.getcwd()+"/bin")
from annocomba.usageinfo import *
from annocomba.utilities import *
#import time
#import subprocess
import argparse
import glob
import yaml

if sys.version_info[0] < 3:
	raise Exception("Must be using Python 3")
	exit(1)

# a few variable definitions 
#singularity_bindpoints = "-B $(pwd)/data/funannotate_database:/data/database"
debug = False
	
pars = argparse.ArgumentParser(usage=help_message(default_help))
pars.add_argument('--debug', action='store_true', dest="debug", required=False)
pars.add_argument('-v', '--version', action='store_true', dest='version', required=False)
pars.add_argument('command', action='store', nargs="?")
pars.add_argument('arguments', action='store', nargs=argparse.REMAINDER)

args = pars.parse_args()

# read singularity bindpoints
def get_bindpoints():
	bp_string = ""
	with open(".bindpoints", "r") as bpfile:
		for line in bpfile:
			bp_string = bp_string + "-B " + line.rstrip() + " "
	#bp_string += "'"
	return bp_string

# add new entry to singularity bindpoint file:
def add_bindpoint(bp):
	# if bindpoint is given with location, first split the bp:
	if ":" in bp:
		if not os.path.isdir(bp.split(":")[0]):
			print(now(), "The directory", bp, "does not exist and will not be mounted in singularity.")
		bp = os.path.abspath(bp.split(":")[0]) + ":" + bp.split(":")[1]
		print("New Bindpoint:", bp)
	else:
		bp = os.path.abspath(bp)
		if not os.path.isdir(bp):
			print(now(), "The directory", bp, "does not exist and will not be mounted in singularity.")
			return 
	with open(".bindpoints", "r") as bpfile:
		for line in bpfile:
			if line.rstrip() == bp:
				if debug:
					print("Bindpoint", bp, "already in .bindpoints. Will not add anything.")
				return
	with open(".bindpoints", "a") as bpfile:
		print(bp, file=bpfile)	

def get_commit():
		return str(subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD']).decode('ascii').strip())

def get_additional_snakemake_flags(flags, rerun):
	if flags:
		flags= flags.strip() #need to remove trailing charcters such as spaces first otherwise the list will be messed up
	if rerun: # add --rerun-incomplete in case it is set
		if flags: #add depending on if flags already contains values or not
			flags += " --rerun-incomplete"
		else:
			flags += "--rerun-incomplete"
	if flags:
		print(now(), "INFO: Additional flags will be passed on to snakemake: ", flags)
		return flags.split(" ")
	else:
		return []

def get_additional_singularity_flags(flags):
	if flags:
		print(now(), "INFO: Additional flags will be passed on to singularity: ", flags)
		return ["--singularity-args"]+[get_bindpoints() +" " + flags]
	else:
		return ["--singularity-args"]+ [get_bindpoints()]

if args.version == True:
	commit = get_commit()
	print("Version:", version)
	print("Git commit:", commit)
	sys.exit(0)

if args.debug == True:
	print(now(), "DEBUG: Addditional debugging output enabled.")
	debug=True

if not args.command:
	print(default_help)
	sys.exit(0)

class AnnoParser(argparse.ArgumentParser):
	def __init__(self, **kwargs):
		super().__init__(**kwargs)
		self.add_argument("-f", "--force", action="store_true" )
		self.add_argument("-F", "--FORCE", action="store_true" )
		self.add_argument("-t", "--cluster",  action="store", default="local")
		self.add_argument("-c", "--cluster-config", action="store")
		self.add_argument("--dry", action="store_true")
		self.add_argument("-h", "--help", action="store_true")
		self.add_argument("--verbose", action="store_true", default=False)	
		self.add_argument("--singularity", action="store",dest="si_args", default="")
		self.add_argument("--snakemake", action="store",dest="sm_args", default="")
		self.add_argument("--rerun-incomplete", action="store_true", dest="rerun", default=False)

if args.command == "setup":
	print(now(), "Welcome to annocomba setup v%s" % version)
	setup_parser = AnnoParser(usage=help_message(setup_help), add_help=False)
	
	setup_parser.add_argument("--all", action="store_true", dest="all", default=False)
	setup_parser.add_argument("--maker", action="store_true", dest="maker", default=False)
	setup_parser.add_argument("--funannotate", action="store_true", dest="funannotate", default=False)
	setup_parser.add_argument("--eggnog", action="store_true", dest="eggnog", default=False)
	setup_parser.add_argument("--genemark", action="store_true", dest="genemark", default=False)
	setup_parser.add_argument("--signalp", action="store_true", dest="signalp", default=False)
	setup_parser.add_argument("--config-file", action="store", dest="configf", default="data/config.yaml")
	setup_args = setup_parser.parse_args(args.arguments)
	if setup_args.help or len(sys.argv) <= 2:
		print(help_message(setup_help))
		sys.exit(0)

	cmd = ["snakemake", "-s", "rules/setup.Snakefile", "--use-singularity", "-r"]
	if setup_args.funannotate:
		add_bindpoint("data/funannotate_database:/data/database")
		cmd.append("setup_funannotate")
	if setup_args.maker:
		cmd.append("setup_maker")
	if setup_args.eggnog:
		with open(setup_args.configf, 'r') as file:
			config_entries = yaml.safe_load(file)
			add_bindpoint(config_entries["eggnog_database_path"])
		cmd.append("setup_eggnog")
	if setup_args.genemark:
		cmd.append("setup_genemark")
	if setup_args.signalp:
		cmd.append("setup_signalp")
	if setup_args.all:
		add_bindpoint("data/funannotate_database:/data/database")
		with open(setup_args.configf, 'r') as file:
			config_entries = yaml.safe_load(file)
			add_bindpoint(config_entries["eggnog_database_path"])
		cmd = ["snakemake", "-s", "rules/setup.Snakefile", "--use-singularity", "-r"]
		cmd = cmd + ["setup_signalp","setup_genemark","setup_eggnog","setup_maker","setup_funannotate"]

	cmd += get_flags(vars(setup_args), debug)
	cmd += determine_submission_mode(setup_args.cluster)

	cmd += get_additional_snakemake_flags(setup_args.sm_args, setup_args.rerun)
	cmd += get_additional_singularity_flags(setup_args.si_args)

	for line in execute_command(cmd, setup_args.verbose):
		print(line, end="\r")
	if debug:
		print(now(),"DEBUG:", cmd)
	# now that setup has run we can add the bindpoints (before they don't exist)
	if setup_args.signalp:
		add_bindpoint("bin/SignalP")
	if setup_args.genemark:
		add_bindpoint("bin/Genemark")
