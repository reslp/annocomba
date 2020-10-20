#!/usr/bin/env python3

import os
import sys
import shutil

from snakemake.utils import read_job_properties

print(sys.argv, file=sys.stderr)
# last command-line argument is the job script
jobscript = sys.argv[-1]

# last but one argument is the submission system
subs = sys.argv[-2]
print("Submission system:", subs,file=sys.stderr)

# check command-line arguments for dependencies
dependencies = ""
if subs == "slurm":
	dependencies = set(sys.argv[1:-2])
elif subs == "sge":
	dependencies = dependencies.join(sys.argv[1:-2])
else:
	print("Cannot get dependencies for submission system")
	sys.exit(1)
print("Dependencies:", file=sys.stderr)
print(dependencies, file=sys.stderr)


# parse the job script for the job properties that are encoded by snakemake within
# this also includes the information contained in the cluster-config file as job_properties["cluster"]
job_properties = read_job_properties(jobscript)
print(job_properties, file=sys.stderr)
print(job_properties["wildcards"], file=sys.stderr)

sample = ""
#find the sample name from the Snakemake rule properties (this assumes that in the Snakefile there exists a wildcard 'sample')
if "sample" in job_properties["wildcards"]:
        sample = job_properties["wildcards"]["sample"]

#add a unit to the sample name (assumes that there is a wildcard 'unit', in our snakefile this is the number of the partitions)
if "unit" in job_properties["wildcards"]:
	sample = sample+"-"+job_properties["wildcards"]["unit"]

#add a aed to the sample name (assumes that there is a wildcard 'aed', in our snakefile this is relevant for the Augustus runs)
if "aed" in job_properties["wildcards"]:
	sample = sample+"-"+job_properties["wildcards"]["aed"]

cmdline=[]
# create list with command line arguments
if subs == "slurm":
	cmdline = ["sbatch"]
	if "sample" in job_properties["wildcards"]:
                job_properties["cluster"]["J"] = job_properties["cluster"]["J"]+"-"+sample
                prefix = sample + "-" + job_properties["rule"] + "-slurm"
                job_properties["cluster"]["output"] = job_properties["cluster"]["output"].replace("slurm", prefix)
                job_properties["cluster"]["error"] = job_properties["cluster"]["error"].replace("slurm", prefix)
	
	#determine threads from the Snakemake profile, i.e. as determined in the Snakefile and the main config file respectively
	job_properties["cluster"]["ntasks"] = job_properties["threads"]
	job_properties["cluster"]["ntasks-per-node"] = job_properties["threads"]

	# create string for slurm submit options for rule
	slurm_args = "--partition={partition} --time={time} --qos={qos} --ntasks={ntasks} --ntasks-per-node={ntasks-per-node} --hint={hint} --output={output} --error={error} -n {n} -J {J} --mem={mem}".format(**job_properties["cluster"])
	cmdline.append(slurm_args)
	# now work on dependencies
	if dependencies:
		cmdline.append("--dependency")
		# only keep numbers (which are the jobids) in dependencies list. this is necessary because slurm returns more than the jobid. For other schedulers this could be different!
		dependencies = [x for x in dependencies if x.isdigit()]
		cmdline.append("afterok:" + ":".join(dependencies))
		#print("Dep:", file=sys.stderr)
		#print(dependencies, file=sys.stderr)
elif subs == "sge":
	if "sample" in job_properties["wildcards"]:
		name = job_properties["cluster"]["N"] + "_" + sample 
	else:
		name = job_properties["cluster"]["N"]
	job_properties["cluster"]["N"] = name
	prefix = "comparative-" + job_properties["rule"] + "-sge"
	job_properties["cluster"]["output"] = job_properties["cluster"]["output"].replace("slurm", prefix).replace("%j",name)
	job_properties["cluster"]["error"] = job_properties["cluster"]["error"].replace("slurm", prefix).replace("%j",name)
	cmdline = ["qsub"]
	
	#determine threads from the Snakemake profile, i.e. as determined in the Snakefile and the main config file respectively
	job_properties["cluster"]["ntasks"] = job_properties["threads"]
	
	sge_args = "-cwd -V -q {queue} -l h_vmem={mem} -pe {pe} {ntasks} -o {output} -e {error} -N {N}".format(**job_properties["cluster"])	
	cmdline.append(sge_args)

	#now work on dependencies
	if dependencies:
		cmdline.append("-hold_jid")
		# only keep numbers (which are the jobids) in dependencies list. this is necessary because slurm returns more than the jobid. For other schedulers this could be different!
		dependencies = [x for x in dependencies.split(" ") if x.isdigit()]
		cmdline.append(",".join(dependencies))
		print(dependencies, file=sys.stderr)
	else:
		print("No dependencies will be passed to qsub", file=sys.stderr)	
	# add @:
	#cmdline.append("-@")
else:
	#print("Immediate submit error: Unkown submission system!")
	sys.exit(1)


cmdline.append(jobscript)


#now write final commandback to the system
print(" ".join(cmdline), file=sys.stderr)
os.system(" ".join(cmdline))


