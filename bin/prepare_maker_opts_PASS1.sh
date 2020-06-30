#!/bin/bash

snaphmm=$1
nr_evidence=$2
busco_proteins=$3
repmod_lib=$4
repmas_gff=$5
alt_est=$6
est=$7

#add SNAP result if present
if [ -f "$snaphmm" ]
then
	echo -e "SNAP hmms provided: $snaphmm"
	sed -i "s?snaphmm= ?snaphmm=$snaphmm ?" maker_opts.ctl
fi
#add protein evidence if present
if [ -f "$nr_evidence" ] || [ -f "$busco_proteins" ]
then
	paths=""
	if [ -f "$nr_evidence" ]; then echo -e "Protein evidence provided: $nr_evidence"; paths="$paths,$nr_evidence"; fi
	if [ -f "$busco_proteins" ]; then echo -e "BUSCO proteins provided: $busco_proteins"; paths="$paths,$busco_proteins"; fi
	paths=$(echo $paths | sed 's/^,//')
	sed -i "s?protein= ?protein=$paths ?" maker_opts.ctl
fi
#add denovo repeat library if present
if [ -f "$repmod_lib" ]
then
        echo -e "Denovo repeat library provided: $repmod_lib"
        sed -i "s?rmlib= ?rmlib=$repmod_lib ?" maker_opts.ctl
fi
#add repeatmasker gff if present
if [ -f "$repmas_gff" ]
then
	echo -e "Repeatmasker gff provided: $repmas_gff"
	sed -i "s?rm_gff= ?rm_gff=$repmas_gff ?" maker_opts.ctl
fi

if [ ! -z "$alt_est" ]
then
	echo -e "Transcriptome evidence (altest) provided: $alt_est"
	sed -i "s?altest= ?altest=$(echo $alt_est | sed 's/altest=//' | sed 's/ /,/g') ?" maker_opts.ctl
fi

if [ ! -z "$est" ]
then
	echo -e "Transcriptome evidence (est) provided: $est"
	sed -i "s?^est= ?est=$(echo $est | sed 's/est=//' | sed 's/ /,/g') ?" maker_opts.ctl
fi

sed -i 's/est2genome=0/est2genome=1/' maker_opts.ctl
sed -i 's/protein2genome=0/protein2genome=1/' maker_opts.ctl
