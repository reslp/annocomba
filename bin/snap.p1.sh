#!/bin/bash

prefix=$1
gff=$2
fasta=$3


echo -e "[$(date)]\tConvert CEGMA gff to SNAP input"
cegma2zff $gff $fasta
retVal=$(( retVal + $? ))

echo -e "[$(date)]\tgather some stats and validate"
fathom genome.ann genome.dna -gene-stats > gene-stats.log 2>&1
fathom genome.ann genome.dna -validate > validate.log 2>&1
retVal=$(( retVal + $? ))

echo -e "[$(date)]\tcollect the training sequences and annotations, plus 1000 surrounding bp for training"
fathom genome.ann genome.dna -categorize 1000
fathom -export 1000 -plus uni.ann uni.dna
retVal=$(( retVal + $? ))

echo -e "[$(date)]\tcreate the training parameters"
forge export.ann export.dna
retVal=$(( retVal + $? ))

echo -e "[$(date)]\tassemble the HMMs"
hmm-assembler.pl $prefix . > $prefix.cegma.snap.hmm
retVal=$(( retVal + $? ))

if [ ! $retVal -eq 0 ]
then
	echo "There was some error" 1>&2
	exit $retVal
fi
