# A flexible genome annotation pipeline combining funannotate and MAKER, snakemake and singularity

## **Prerequisites**

- A Linux cluster
- globally installed SLURM 18.08.7.1
- globally installed singularity 3.4.1+ 
- installed snakemake 5.19.3 (eg. in an anaconda environment)

## Rulegraph

<img src="https://github.com/reslp/annocomba/blob/master/rulegraph.png" eight="500">

## Issues (inherited from smsi-funannotate):
- Sauron: There is a strange issue with RepeatMasker. For some reason it does not run. ReapearMasking with TanTan works fine.
- Sauron: I have had many jobs failing due to a singularity error: `FATAL:   container creation failed: failed to resolved session directory`. This does not occur on VSC. From the extended message: `Activating singularity image /cl_tmp/reslph/projects/xylographa_fun/.snakemake/singularity/195cc8bdbe1d3f304062822f8f4f06ce.simg
FATAL:   container creation failed: failed to resolved session directory /usertmp/singularity/mnt/session: lstat /tmp/singularity: no such file or directory` I assume it has to do with the tmp directory not being present. I have seen this after the jobs have been in the queue for a week (and other jobs ran fine). Maybe the /tmp directory is automatically deleted from time to time which causes this error.

## **Setup annocomba**

```
$ git clone git@github.com:reslp/annocomba.git
$ ./annocomba --setup
```

