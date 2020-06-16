#!/usr/bin/env python3

import os
import sys

from snakemake.utils import read_job_properties

# last command-line argument is the job script
jobscript = sys.argv[-1]

# all other command-line arguments are the dependencies
dependencies = set(sys.argv[1:-1])

# parse the job script for the job properties that are encoded by snakemake within
# this also includes the information contained in the cluster-config file as job_properties["cluster"]
job_properties = read_job_properties(jobscript)

sample = ""
#find the sample name from the Snakemake rule properties (this assumes that in the Snakefile there exists a wildcard 'sample')
if "sample" in job_properties["wildcards"]:
        sample = job_properties["wildcards"]["sample"]

#add a unit to the sample name (assumes that there is a wildcard 'unit', in our snakefile this is the number of the partition)
if "unit" in job_properties["wildcards"]:
	sample = sample+"-"+job_properties["wildcards"]["unit"]

#add the sample name (this assumes that in the Snakefile there exists a wildcard 'sample') to the Jobname specified in the cluster_config file
if len(sample) > 0:
	job_properties["cluster"]["J"] = job_properties["cluster"]["J"]+"-"+sample

#add rule name to log files (assumes that the log files, as specified in the cluster_config file ends in 'stdout.txt' or 'stderr.txt')
job_properties["cluster"]["output"] = job_properties["cluster"]["output"].replace("stdout.txt", job_properties["rule"]+"."+sample+".stdout.txt")
job_properties["cluster"]["error"] = job_properties["cluster"]["error"].replace("stderr.txt", job_properties["rule"]+"."+sample+".stderr.txt")

#determine threads from the Snakemake profile, i.e. as determined in the Snakefile and the main config file respectively
job_properties["cluster"]["ntasks"] = job_properties["threads"]
job_properties["cluster"]["ntasks-per-node"] = job_properties["threads"]

# create list with command line arguments
cmdline = ["sbatch"]

# create string for slurm submit options for rule
slurm_args = "--partition={partition} --qos={qos} --mem={mem} --ntasks={ntasks} --ntasks-per-node={ntasks-per-node} --time={time} --hint={hint} --output={output} --error={error} -N {N} -J {J}".format(**job_properties["cluster"])
cmdline.append(slurm_args)

# now work on dependencies
if dependencies:
    cmdline.append("--dependency")
    # only keep numbers (which are the jobids) in dependencies list. this is necessary because slurm returns more than the jobid. For other schedulers this could be different!
    dependencies = [x for x in dependencies if x.isdigit()]
    cmdline.append("afterok:" + ":".join(dependencies))

cmdline.append(jobscript)

#now write final commandback to the system
os.system(" ".join(cmdline))
