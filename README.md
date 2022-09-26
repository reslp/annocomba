# A flexible genome annotation pipeline combining funannotate and MAKER, snakemake and singularity

## **Prerequisites**

- Access to a Linux based HPC cluster (local execution is possible but dicouraged)
- globally installed SLURM, SGE or TORQUE job management system.
- globally installed singularity 3.4.1+ 
- installed snakemake 6.0.2 (eg. in an anaconda environment)

## IMPORTANT

Annocomba is still under developement. While everything generally works, it can also happen that you will run into problems.


## Getting annocomba

Installing annocomba is simple. You need to clone the repository and you are good to go. While annocomba itself only has two dependencies (Singuilarity and Snakemake) there are a few additional dependencies which are required to unlock its full functionality.

```
$ git clone --recursive https://github.com/reslp/annocomba.git
$ cd annocomba
$ ./annocomba


			     Welcome to annocomba v0.1

Usage: annocomba <command> <arguments>
Commands:
	setup			Setup pipeline
	call-genes		De-novo gene-calling using different software
	annotate		Produce functional annotations for called genes

	util			Utilities
	-v, --version 		Print version
	-h, --help		Display help
Examples:
	To see options for the setup step:
	./annocomba setup -h

```



## Rulegraph

<img src="https://github.com/reslp/annocomba/blob/master/rulegraph.png" eight="500">

## Issues (inherited from smsi-funannotate):
- Sauron: There is a strange issue with RepeatMasker. For some reason it does not run. ReapearMasking with TanTan works fine.
- Sauron: I have had many jobs failing due to a singularity error: `FATAL:   container creation failed: failed to resolved session directory`. This does not occur on VSC. From the extended message: `Activating singularity image /cl_tmp/reslph/projects/xylographa_fun/.snakemake/singularity/195cc8bdbe1d3f304062822f8f4f06ce.simg
FATAL:   container creation failed: failed to resolved session directory /usertmp/singularity/mnt/session: lstat /tmp/singularity: no such file or directory` I assume it has to do with the tmp directory not being present. I have seen this after the jobs have been in the queue for a week (and other jobs ran fine). Maybe the /tmp directory is automatically deleted from time to time which causes this error.


