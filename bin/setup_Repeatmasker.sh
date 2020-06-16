#!/bin/bash

#use as ./setup_Repeatmasker.sh destination/ external/RepBaseRepeatMaskerEdition-20181026.tar.gz

destination=$1
repeattarball=$2

#take care of RepeatMasker
cp -pfr /usr/local/RepeatMasker $destination
#cd $destination/RepeatMasker
#perl ./rebuild
#cd -
tar xvfz $repeattarball -C $destination/RepeatMasker/

#This is a custom step that checks the metadata against the actual sequence data and removes those that are not present in the metadata
cd $destination/RepeatMasker
echo "Checking Repbase metadata against sequence data"
cat Libraries/RMRBSeqs.embl | grep "^ID " | sed 's/^ID   //' | cut -d " " -f 1 | sort -n | uniq | perl -ne 'chomp; print "$_\n$_\n"' > comp1
cat Libraries/RMRBMeta.embl | grep "^ID " | sed 's/^ID   //' | cut -d " " -f 1 | sort -n | uniq > comp2
cat comp1 comp2 | sort -n | uniq -c | grep "   1 " | sed 's/^ .*1 //' > missing
for m in $(cat missing); do sed -i "/$m/,/\/\//d" Libraries/RMRBMeta.embl; done
rm comp1 comp2 missing

#BUild the repeatdatabases
perl ./rebuild

