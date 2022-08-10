import sys, os
import time
import subprocess
import logging
import io

def now():
	return time.strftime("%Y-%m-%d %H:%M") + " -"

def progressbar(it, progress, prefix="", size=60, file=sys.stdout):
	count = len(it)
	def show(j):
		x = int(size*j/count)
		return "%s[%s%s] %i/%i\r" % (prefix, "#"*x, "."*(size-x), j, count)
	return show(progress)

def help_message(mes):
	return mes

def determine_submission_mode(flag, njobs):
	cmd = []
	if "serial" in flag:
		return ["--cores" + flag.replace("serial","")]
	elif "local" in flag:
		return ["--cores" + flag.replace("local", "")]
	elif "sge" in flag: # for SGE the dependencies need to be under quotes, because there are () characters in the dependency string.
		return ["--cluster", "bin/immediate-submit/immediate_submit.py '{dependencies}' %s" % flag, "--immediate-submit", "--jobs", njobs, "--notemp"]
	else:
		return ["--cluster", 'bin/immediate-submit/immediate_submit.py {dependencies} %s' % flag, "--immediate-submit", "--jobs", njobs, "--notemp"]

def get_flags(flags, debug):
	mapdict ={
	#"t": '--cluster "bin/immediate_submit.py {dependencies} ', "cluster": '--cluster "bin/immediate_submit.py {dependencies} ',
	"c": "--cluster-config", "cluster_config": "--cluster-config",
	"FORCE": "-F",
	"force": "-f",
	"dry": "-n"
	}
	cmd = []
	if debug:
		print(now(), "DEBUG: flags: ", flags)
	if flags["cluster_config"] == None and not "serial" in flags["cluster"] and not "local" in flags["cluster"]: #in case no cluster config file was specified, get default value
		ccf = cluster_config_defaults[flags["cluster"]]
		flags["cluster_config"] = ccf
		print(now(), "INFO: No cluster config file specified. Will try to use default file: %s" % ccf)	
	else:
		ccf = flags["cluster_config"]
		if ccf != None:
			if not os.path.isfile(ccf):
				print(now(), "ERROR: Specified cluster config file:", ccf, "not found.")
				sys.exit(1)
	for flag in flags.keys():
		if flag in mapdict.keys() and flags[flag] != None:
			if flag == "t" or flag == "cluster": #handle cluster specification
				arg = mapdict[flag]
				arg = arg + " "+flags[flag]+'"'
				cmd.append(arg) 
			if flag == "c" or flag == "cluster_config": #handle cluster config file
				#print("here")
				#arg = mapdict[flag]
				#arg = arg + " " + flags[flag]
				cmd.append(mapdict[flag])
				cmd.append(ccf)
			else:
				if flags[flag]:
					cmd.append(mapdict[flag])
	
	return cmd

def check_for_errors(result):
	if result.startswith("WorkflowError"):
		return now()+" ERROR: annocomba encountered an error. You may try to run with --verbose to diagnose what has gone wrong.\n"
	if result.startswith("The singularity command"):
		return result
	if result.startswith("Error") or result.startswith("error"):
		return now()+" ERROR: There was an error. Maybe run with --verbose to diagnose. The error occurred here: %s " % result	
	if result.startswith("Directory cannot be locked."):
		return now()+" ERROR: "+result	
	if result.startswith("IncompleteFilesException"):
		return now()+" ERROR: There seems to be a problem with incomplete output files from a previous run.\nYou can run --verbose to see which files are incomplete and how to resolve the problem.\n"
	if result.startswith("KeyError"):
		return now()+" ERROR: "+result
	return ""

def execute_command(cmd, verbose, isutil=False):
	# this should also correctly parse and display:
	# IncompleteFilesException
	# when singularity command is not available
	popen = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
	line = ""
	jobcounts = False
	njobs = 0
	char = ""
	nline = 0
	curr_task = 0
	if not os.path.isdir("log/annocomba"):
		os.mkdir("log/annocomba")
	if "-n" in cmd:
		print(now(), "INFO: --dry specified, will only perform a dry run of the analysis")
		for line in io.TextIOWrapper(popen.stdout, encoding="utf-8"):
			nline += 1
			if verbose:
				yield line
			else:
				result = line
				if check_for_errors(result):
					yield check_for_errors(result)
				if result.startswith("Nothing"):
					yield now() + " There is nothing to do. If you want to force a rerun of this step try: -f or --force\n"
				if result.startswith("Job counts"):
					jobcounts = True
				elif jobcounts and result != "" and nline <= 30: #only keep jobcount info from the beginning of the output
					if len(result.split("\t")) == 2: # the line with the total number of jobs has two elements
						yield now()+" Total number of tasks to run/submit: %s\n" % result.split("\t")[1].strip() 
				elif jobcounts and result == "":
					jobcounts = False
				line=""
	elif "--cluster" in cmd:
		if not isutil:
			logging.basicConfig(filename="log/annocomba/annocomba-log-" + time.strftime("%Y-%m-%d_%H-%M-%S") + ".txt", level=logging.DEBUG,format="%(message)s")	
			logging.debug("ANNOCOMBA COMMAND: " + " ".join(sys.argv))
			logging.debug("EXECUTED COMMAND: " + " ".join(cmd))
		for line in io.TextIOWrapper(popen.stdout, encoding="utf-8"):
			nline += 1
			logging.debug(line.strip())
			if verbose:
				if line.startswith("Pulling singularity"):
					container = line.rstrip().split(" ")[-1].strip(".")
					yield now() + " Please be patient as singularity container " + container + " is downloaded. This can take several minutes.\n"
				yield line
			else:
				result = line
				if check_for_errors(result):
					yield check_for_errors(result)
				if result.startswith("Singularity"):
					yield result
				if result.startswith("Job counts"):
					jobcounts = True	
				if result.startswith("Pulling singularity"):
					container = result.rstrip().split(" ")[-1].strip(".")
					yield now() + " Please be patient as singularity container " + container + " is downloaded. This can take several minutes.\n"
				elif jobcounts and result != "" and nline <= 30: #only keep jobcount info from the beginning of the output
					if len(result.split("\t")) == 2: # the line with the total number of jobs has two elements
						yield now()+" Total number of jobs to submit: %s\n" % result.split("\t")[1].strip()
						njobs = int(result.split("\t")[1])
				elif jobcounts and result == "":
					jobcounts = False
				if line.startswith("rule"):
					curr_task += 1
					yield progressbar(range(njobs),curr_task, "Submitting: ", 100)
				line=""
	else:
		if not isutil:
			logging.basicConfig(filename="log/annocomba/annocomba-log-" + time.strftime("%Y-%m-%d_%H-%M-%S") + ".txt", level=logging.DEBUG,format="%(message)s")	
			logging.debug("ANNOCOMBA COMMAND: " + " ".join(sys.argv))
			logging.debug("EXECUTED COMMAND: " + " ".join(cmd))
		for line in io.TextIOWrapper(popen.stdout, encoding="utf-8"):
			nline += 1
			logging.debug(line.strip())
			if verbose:
				if line.startswith("Pulling singularity"):
					container = line.rstrip().split(" ")[-1].strip(".")
					yield now() + " Please be patient as singularity container " + container + " is downloaded. This can take several minutes.\n"
				yield line
			else:
				result = line
				if check_for_errors(result):
					yield check_for_errors(result)
				if result.startswith("Nothing"):
					yield now()+" There is nothing to do. If you want to force a rerun of this step try: -f or --force\n"
				if result.startswith("Job counts"):
					jobcounts = True	
				if result.startswith("Pulling singularity"):
					container = result.rstrip().split(" ")[-1].strip(".")
					yield now() + " Please be patient as singularity container " + container + " is downloaded. This can take several minutes.\n"
				elif jobcounts and result != "" and nline <= 30: #only keep jobcount info from the beginning of the output
					if len(result.split("\t")) == 2: # the line with the total number of jobs has two elements
						yield now()+" Total number of tasks to run: %s\n" % result.split("\t")[1].strip()
						njobs = int(result.split("\t")[1])
				elif jobcounts and result == "":
					jobcounts = False
				if line.startswith("rule"):
					curr_task += 1
					yield progressbar(range(njobs),curr_task, "Runnning: ", 100)
				line=""

