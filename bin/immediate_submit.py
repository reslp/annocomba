#!/usr/bin/env python3

import os
import sys
import shutil

from snakemake.utils import read_job_properties


#print(sys.argv)
# last command-line argument is the job script
jobscript = sys.argv[-1]
#print(jobscript)
# last but one argument is the submission system
subs = sys.argv[-2]
#print(subs)

# all other command-line arguments are the dependencies
if sys.argv[1:-2] != [""]:
	dependencies = str(sys.argv[1:-2])
	#print("Dependencies found")
	#print(sys.argv[1:-2])
else:
	dependencies = ""
# parse the job script for the job properties that are encoded by snakemake within
# this also includes the information contained in the cluster-config file as job_properties["cluster"]
job_properties = read_job_properties(jobscript)
print(job_properties, file=sys.stderr)
print(job_properties["wildcards"], file=sys.stderr)

cmdline=[]
# create list with command line arguments
if subs == "slurm":
	cmdline = ["sbatch"]
	if "sample" in job_properties["wildcards"]:
                job_properties["cluster"]["J"] = job_properties["cluster"]["J"]+"-"+job_properties["wildcards"]["sample"]
                prefix = job_properties["wildcards"]["sample"] + "-" + job_properties["rule"] + "-slurm"
                job_properties["cluster"]["output"] = job_properties["cluster"]["output"].replace("slurm", prefix)
                job_properties["cluster"]["error"] = job_properties["cluster"]["error"].replace("slurm", prefix)
	# create string for slurm submit options for rule
	slurm_args = "--partition={partition} --time={time} --qos={qos} --ntasks={ntasks} --ntasks-per-node={ntasks-per-node} --hint={hint} --output={output} --error={error} -N {N} -J {J}".format(**job_properties["cluster"])
	cmdline.append(slurm_args)

	# now work on dependencies
	if dependencies != "":
		cmdline.append("--dependency")
		# only keep numbers (which are the jobids) in dependencies list. this is necessary because slurm returns more than the jobid. For other schedulers this could be different!
		dependencies = [x for x in dependencies if x.isdigit()]
		cmdline.append("afterok:" + ",".join(dependencies))
		print(dependencies, file=sys.stderr)
if subs == "sge":
	if "sample" in job_properties["wildcards"]:
		name = job_properties["wildcards"]["sample"] + "_" + job_properties["cluster"]["N"] 
	else:
		name = job_properties["cluster"]["N"]
	job_properties["cluster"]["N"] = name
	prefix = "comparative-" + job_properties["rule"] + "-sge"
	job_properties["cluster"]["output"] = job_properties["cluster"]["output"].replace("slurm", prefix).replace("%j",name)
	job_properties["cluster"]["error"] = job_properties["cluster"]["error"].replace("slurm", prefix).replace("%j",name)
	cmdline = ["qsub"]
	sge_args = "-cwd -V -q {queue} -l h_vmem={mem} -pe {queue} {ntasks} -o {output} -e {error} -N {N}".format(**job_properties["cluster"])	
	cmdline.append(sge_args)

	#now work on dependencies
	if dependencies != "":
		cmdline.append("-hold_jid")
		# only keep numbers (which are the jobids) in dependencies list. this is necessary because slurm returns more than the jobid. For other schedulers this could be different!
		dependencies = [x for x in dependencies.split(" ") if x.isdigit()]
		cmdline.append(",".join(dependencies))
		print(dependencies, file=sys.stderr)
else:
	#print("Immediate submit error: Unkown submission system!")
	sys.exit(1)


cmdline.append(jobscript)


#now write final commandback to the system
print(" ".join(cmdline), file=sys.stderr)
os.system(" ".join(cmdline))


