#!/bin/bash

prefix=$1
gff=$2
aed=$3

#Extract gene models with AED <= x
echo -e "[$(date)]\tIdentify gene models with AED score > $aed"
cat <(echo -e "$aed") <(cat $gff | grep -P "\tmRNA") | perl -ne 'chomp; if ($. == 1){$aed_max=$_}else{@a=split("\t"); @b=split(";",$a[8]);for (@b){if ($_ =~ /_AED/){$_ =~ s/_AED=//; $AED=$_; if ($AED > $aed_max){$b[0] =~ s/ID=//; print "$b[0]\n"; $b[0] =~ s/-mRNA.*//; print "$b[0];\n"}}}}' > gt.$aed.ids.txt

echo -e "[$(date)]\tExclude these gene models from gff -> remainder written to file: MAKER.st$aed.maker.gff"
grep -v -f gt.$aed.ids.txt $gff > MAKER.st$aed.maker.gff

echo -e "[$(date)]\tConvert MAKER gff to SNAP input"
maker2zff -n MAKER.st$aed.maker.gff

echo -e "[$(date)]\tgather some stats and validate"
fathom genome.ann genome.dna -gene-stats > gene-stats.log 2>&1
fathom genome.ann genome.dna -validate > validate.log 2>&1
echo -e "[$(date)]\tcollect the training sequences and annotations, plus 1000 surrounding bp for training"
fathom genome.ann genome.dna -categorize 1000
fathom -export 1000 -plus uni.ann uni.dna
echo -e "[$(date)]\tcreate the training parameters"
forge export.ann export.dna
echo -e "[$(date)]\tassemble the HMMs"
hmm-assembler.pl $prefix . > $prefix.MAKER.st$aed.snap.hmm

ln -s $prefix.MAKER.st$aed.snap.hmm $prefix.MAKER_PASS1.snap.hmm
