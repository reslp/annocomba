#!/bin/bash

snaphmm=$1
augustus_species=$2
params=$3
pred_gff=$4
rm_gff=$5
protein_gff=$6
altest_gff=$7
est_gff=$8
local_config=$9

if [ -s "$est_gff" ]
then
	echo -e "Transcriptome evidence (est) previously provided: $est_gff"
	sed -i "s?^est_gff= ?est_gff=$est_gff ?" maker_opts.ctl
fi
if [ -s "$altest_gff" ]
then
	echo -e "Transcriptome evidence (altest) previously provided: $altest_gff"
	sed -i "s?^altest_gff= ?altest_gff=$altest_gff ?" maker_opts.ctl
fi
if [ -s "$protein_gff" ]
then
	echo -e "Protein evidence previously provided: $protein_gff"
	sed -i "s?^protein_gff= ?protein_gff=$protein_gff ?" maker_opts.ctl
fi
if [ -s "$rm_gff" ]
then
	echo -e "Repeat models previously provided: $rm_gff"
	sed -i "s?^rm_gff= ?rm_gff=$rm_gff ?" maker_opts.ctl
fi
if [ -s "$snaphmm" ]
then
	echo -e "SNAP hmms provided: $snaphmm"
	sed -i "s?snaphmm= ?snaphmm=$snaphmm ?" maker_opts.ctl
fi
if [ $augustus_species ] && [ -d "$params" ]
then
	echo -e "AUGUSTUS species will be set to: $augustus_species"
	echo -e "training parameters provided at: $params"
	sed -i "s?augustus_species= ?augustus_species=$augustus_species ?" maker_opts.ctl
	ln -s $params $local_config/species/$augustus_species
else
	echo -e "WARNING! No valid Augustus species with trained models provided"
fi
if [ -s "$pred_gff" ]
then
	echo -e "Ab-initio predictions (AUGUSTUS) provided: $pred_gff"
	sed -i "s?pred_gff= ?pred_gff=$pred_gff ?" maker_opts.ctl
fi

#Switch off Repeatmasking based on Model organism
sed -i 's/model_org=all/model_org= /' maker_opts.ctl

#for PASS2
sed -i 's/keep_preds=0/keep_preds=1/' maker_opts.ctl

