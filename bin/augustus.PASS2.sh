#!/bin/bash

threads=$1
prefix=$2
fasta=$3
proteins=$4
aed=$5
local_config=$6
training_params=$7
cdna=$8
extra_parameters=$9

AUGUSTUS_CONFIG_PATH=$local_config

basedir=$(pwd)
#prepare training parameters from BUSCO
if [ ! -z $training_params ]
then
	echo -e "[$(date)]\tPreparing training set Augustus"
	if [[ "$training_params" == "from_scratch" ]]
	then
		echo -e "[$(date)]\tStarting from scratch"
		new_species.pl --species=$prefix 
	else
		echo -e "[$(date)]\tResume training from previous BUSCO run ('$training_params')"

		#get local copy of Augustus parameters from previous training round
		cp -fr $training_params $local_config/species/$prefix

		cd $local_config/species/
		#remove all but the currently relevant models
		rm -rf $(ls -1 | grep -v "$prefix")
		#rename files to current prefix
		cd $prefix
		base=$(ls *weightmatrix.txt | sed 's/_weightmatrix.txt//')
		#rename files
		for file in $(ls -1); do new=$(echo -e "$file" | sed "s/$base/$prefix/g"); mv $file $new; done
		#rename the files cited within certain HMM configuration files
		sed -i "s/$base/$prefix/g" $prefix\_parameters.cfg
		sed -i "s/$base/$prefix/g" $prefix\_parameters.cfg.orig1

		cd $basedir
	fi
fi

if [ ! -z $aed ]
then
	echo -e "[$(date)]\tFiltering proteins for training - retaining only AED <= $aed"
	#extract only proteins with AED < x
	cat <(echo -e "$aed") <(cat $proteins | perl -ne 'chomp; if ($_ =~ /^>/){print "\n$_\n"}else{print "$_"}' | grep -v "^$") | \
perl -ne 'chomp; if ($. == 1){$AED = $_}else{$h=$_; $s=<>; @a=split(" "); $a[2] =~ s/AED://; if ($a[2] <= $AED){print "$h\n$s"}}' | sed 's/ .*//' > $prefix.AED-st$aed.maker.proteins.fasta
	proteins=$prefix.AED-st$aed.maker.proteins.fasta
fi

cmd="autoAug.pl"
if [ ! "$extra_parameters" == "None" ]
then
	echo -e "[$(date)]\tnon-default parameters specified by user: $extra_parameters"
	cmd=$cmd" $extra_parameters"
fi

if [ -f "$cdna" ]
then
	cmd=$cmd" --genome=$fasta --species=$prefix --trainingset=$proteins --cdna=$cdna --singleCPU --threads $threads -v --useexisting"
	echo -e "[$(date)]\tRunning autoAug.pl with cdna evidence:\n$cmd"
else
	cmd=$cmd" --genome=$fasta --species=$prefix --trainingset=$proteins --singleCPU --threads $threads -v --useexisting"
	echo -e "[$(date)]\tRunning autoAug.pl without cdna evidence:\n$cmd"
fi
$cmd
retVal=$?

if [ ! $retVal -eq 0 ]
then
	if [ -s "$(pwd)/autoAug/autoAugPred_abinitio/predictions/augustus.gff" ]
	then
		>&2 echo "Augustus ended in an error, but abinitio predictions are there - continuing .."
	else
		>&2 echo "Augustus ended in an error"
		exit $retVal
	fi
fi

#copy the training set that was produced
cp -rf $local_config/species/$prefix .
rm -rf $local_config

echo -e "[$(date)]Reformatting to $(pwd)/autoAug/autoAugPred_abinitio/predictions/augustus.gff to GFF3 -> $(pwd)/augustus.gff3"
cat autoAug/autoAugPred_abinitio/predictions/augustus.gff | perl -ne 'chomp; @a=split(/\t/); if ($a[2] eq 'gene'){$id=$a[-1]; $a[-1] =~ s/^/ID=/; print join("\t", @a)."\n"}else{if ($_ =~ /;$/){print "$_ Parent=$id\n"}else{print "$_; Parent=$id\n"}}' | sed 's/; /;/g' | sed 's/ /=/g' > augustus.gff3

#cat $(pwd)/autoAug/autoAugPred_abinitio/predictions/augustus.gff | perl -ne 'chomp; @a=split(/\t/); if ($a[2] eq 'gene'){$id=$a[-1]; $a[-1] =~ s/^/ID=/; print join("\t", @a)."\n"}else{if ($_ =~ /;$/){print "$_ Parent=$id\n"}else{print "$_; Parent=$id\n"}}' | sed 's/; /;/g' | sed 's/ /=/g' > $(pwd)/autoAug/autoAugPred_abinitio/predictions/augustus.gff3 

