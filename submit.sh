#!/bin/bash

#module load singularity/3.5.2-gcc-9.1.0-fp2564h
set -e

usage() {
        echo "Welcome to annocomba. This script helps to submit genome annotation jobs to SLURM and SGE clusters with snakemake and singularity"
        echo
        echo "Usage: $0 [-v] [-t <submission_system>] [-c <cluster_config_file>] [-s <snakemke_args>] [-m <mode>]"
        echo
        echo "Options:"
        echo "  -t <submission_system> Specify available submission system. Options: sge, slurm, serial (no submission system). Default: Automatic detection."
        echo "  -c <cluster_config_file> Path to cluster config file in YAML format (mandatory). "
        echo "  -s <snakemake_args> Additional arguments passed on to the snakemake command (optional). snakemake is run with --immediate-submit -pr --notemp --latency-wait 600 --use-singularity --jobs 1001 by default."
        echo "  -i \"<singularity_args>\" Additional arguments passed on to singularity (optional). Singularity is run with -B /tmp:/usertmp by default."
        echo "  -m <mode> Specify runmode, separated by comma. Options: all,maker,funannotate. Default: all"
	echo "  --setup This flag wil setup all programs and settings for running the pipeline."
        1>&2; exit 1; }

version() {
        echo "$0 v0.1"
        exit 0
}
CLUSTER=""
CLUSTER_CONFIg=""
SETUP=""
while getopts ":v:t:c:s:m:" option;
        do
                case "${option}"
                in
                        v) version;;
                        t) CLUSTER=${OPTARG};;
                        c) CLUSTER_CONFIG=${OPTARG};;
                        s) SM_ARGS=${OPTARG};;
                        i) SI_ARGS=${OPTARG};;
                        m) RUNMODE=${OPTARG};;
			-) LONG_OPTARG="${OPTARG#*=}"
				case $OPTARG in
					setup) SETUP="TRUE" ;;
					'' ) break ;;
					*) echo "Illegal option --$OPTARG\n" >&2; usage; exit 2 ;;
				esac ;;	
                        *) echo "Illegal option --$OPTARG\n" >&2; usage;;
                        ?) echo "Illegal option --$OPTARG\n" >&2 usage;;
                esac
        done
if [ $OPTIND -eq 1 ]; then usage; fi


if [[ ! -f ".annocomba_setup.done" ]]; then
	echo "Annocomba has not yet been configured properly."
	echo "Please run: submit.sh --setup"
	exit 1;
fi

# Testing warning
echo "WARNING: The submission script is still in testing mode! Check the snakemake command inside before moving into production!"

# Determine submission system:
if [[ $CLUSTER == "sge" ]]; then
	echo "SGE (Sun Grid Engine) submission system specified. Will use qsub to submit jobs."
elif [[ $CLUSTER == "slurm" ]]; then
	echo "SLURM submission system specified. Will use sbatch to submit jobs."
elif [[ $CLUSTER == "serial" ]]; then
  echo "Serial execution without job submission specified."
else
	echo "No or unknown submission system specified, will try to detect the system automatically."
	CLUSTER=""
	command -v qsub >/dev/null 2>&1 && { echo >&2 "SGE detected, will use qsub to submit jobs."; CLUSTER="sge"; }
	command -v sbatch >/dev/null 2>&1 && { echo >&2 "SLURM detected, will use sbatch to submit jobs."; CLUSTER="slurm"; }
  if [[ $CLUSTER == "" ]]; then
    echo "Submission system could not be detected. You may be able to run the pipeline without job submission."
    exit 1
  fi
fi


# these if cases are still crude and do not cover all possible combinations!
if [[ $RUNMODE == *"all"* ]]; then
  echo "Runmode set to: all. Pipeline will run and combine MAKER and funannotate."
  if [[ $CLUSTER == "slurm" ]]; then
          export CONDA_PKGS_DIRS="$(pwd)/.conda_pkg_tmp"
          mkdir -p .conda_pkg_tmp
          snakemake --use-singularity --singularity-args "-B $(pwd)/data/eggnogdb:/data/eggnogdb -B $(pwd)/data/database:/data/database -B $(pwd)/data/external:/data/external -B $(pwd)/data/RepeatMaskerLibraries:/software/RepeatMasker/Libraries $SI_ARGS" --jobs 1001 --cluster-config $CLUSTER_CONFIG --cluster '$(pwd)/bin/immediate_submit.py {dependencies} slurm' --immediate-submit -pr --notemp --latency-wait 600 $SM_ARGS
  	unset CONDA_PKGS_DIRS
  elif [[ $CLUSTER == "sge" ]]; then
  	snakemake --use-singularity --singularity-args "-B $(pwd)/data/eggnogdb:/data/eggnogdb -B $(pwd)/data/database:/data/database -B $(pwd)/data/external:/data/external -B $(pwd)/data/RepeatMaskerLibraries:/software/RepeatMasker/Libraries $SI_ARGS" --jobs 1001 --cluster-config $CLUSTER_CONFIG --cluster '$(pwd)/bin/immediate_submit.py {dependencies} sge' --immediate-submit -pr --notemp --latency-wait 600 $SM_ARGS
  elif [[ $CLUSTER == "serial" ]]; then
    snakemake --use-singularity --singularity-args "-B $(pwd)/data/eggnogdb:/data/eggnogdb -B $(pwd)/data/database:/data/database -B $(pwd)/data/external:/data/external -B $(pwd)/data/RepeatMaskerLibraries:/software/RepeatMasker/Libraries $SI_ARGS" -pr --notemp $SM_ARGS
  else
          echo "Submission system not recognized"
          exit 1
  fi
elif [[ $RUNMODE == *"maker"* ]]; then
  echo "Runmode set to: maker. Pipeline will run MAKER."
  exit 1
elif [[ $RUNMODE == *"funannotate"* ]]; then
  echo "Runmode set to: funannotate. Pipeline will run funannotate."
  exit 1
else
  echo "Runmode not recognized: $RUNMODE. Available options are: all,maker,funannotate"
  exit 1
fi
