# TODO list

- Check if names are unique, this is important for funannotate compare and probably also relevant in general.
- add genome summary script as alternative to funannotate compare
- add option to run with Docker or Singularity 
- Clean data.csv file (some fields are redundant)
- add check when --setup is run again.
- remove batch number check when annocomba --setup is run
- hack augustus to recognize lower case repeatmasked files for auto training
- fix augustus parallelisation hack 
- make sure assemblies are found both when specified with relative and absolute paths
- check presence of interproscan during setup
- check presence of genemark key file during setup - do dummy genemark run to check that key isnt expired?
- modify annocomba setup part to read in paths to maker, repeatmasker, funanotate, genemark, eggnogg, genemark, interproscan and only run the respective setupp rules if present
- make repeatmasker setup a separate rule and allow repeatmasker setup also if no repbase db is provided (need to change `bin/setup_Repeatmasker.sh`)
- make antismash in rule remote optional

- perhaps it would be better to change the structure of the repo so that when cloned you already get the basic directories in data/ (assemblies, external, etc.), rather than have these in .gitignore, have .gitignore in the directories that ignores all in the respective directory
- Re. change Repeatmasker to lowercase. Repeatmasked fasta is used by Augustus. I forgot about that. Need to adjust augustus command and add `--softmasking=1` so that the softmasked repeats are interpreted correctly. Will have to change the augustus call in the code of autoPred.pl.
