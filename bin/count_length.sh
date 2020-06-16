#!/bin/bash

#./bin/count_length.sh test.fa.gz 100000 5000 count > check
#./bin/count_length.sh test.fa.gz 100000 5000 split > check
#check
#sha256sum -c <(cut -f 1 check) 
#only check for the file in question
#sha256sum -c <(grep -P "test.fa.gz\t" check| cut -f 1)

f=$1
l=$2
m=$3
mode=$4 #could be either 'count' or 'split'

if [ $(echo $f | rev | cut -c 1-3 | rev) == ".gz" ]
then
#	echo gzipped
	if [ "$mode" == "count" ]
	then
		paste <(sha256sum $f) <(echo -e "$l\t$m\t$(cat <(echo -e "$l\t$m") <(zcat $f) | perl -ne 'chomp; if ($. == 1){@a=split("\t"); $cutoff=$a[0]; $minlen=$a[-1]; $counter=1; }else{if ($_ =~ /^>/){if ($. > 2){if ($length >= $minlen){$cum_length+=$length; if ($cum_length >= $cutoff){$counter++; $cum_length=0; }}} $length = 0}else{$length+=length($_)}}}; if (eof()){print "$counter\n"')")
	fi
	if [ "$mode" == "split" ]
	then
		paste <(sha256sum $f) <(echo -e "$l\t$m\t$(cat <(echo -e "$l\t$m") <(zcat $f) | perl -ne 'chomp; if ($. == 1){@a=split("\t"); $cutoff=$a[0]; $minlen=$a[-1]; $counter=1; open(FH, ">", sprintf("%04d", $counter).".fasta")}else{if ($_ =~ /^>/){if ($. > 2){if ($length >= $minlen){$cum_length+=$length; print FH "$header\n$seq\n"; $header = $_; $seq = ""; if ($cum_length >= $cutoff){close FH; $counter++; open(FH, ">", sprintf("%04d", $counter).".fasta"); $cum_length=0; }}}; $header = $_; $seq = ""; $length = 0}else{$length+=length($_); $seq.=$_}}}; if (eof()){print "$counter\n"; if ($length >= $minlen){print FH "$header\n$seq\n"}')")
	fi
else
#	echo not gzipped
	if [ "$mode" == "count" ]
	then
		paste <(sha256sum $f) <(echo -e "$l\t$m\t$(cat <(echo -e "$l\t$m") $f | perl -ne 'chomp; if ($. == 1){@a=split("\t"); $cutoff=$a[0]; $minlen=$a[-1]; $counter=1; }else{if ($_ =~ /^>/){if ($. > 2){if ($length >= $minlen){$cum_length+=$length; if ($cum_length >= $cutoff){$counter++; $cum_length=0; }}} $length = 0}else{$length+=length($_)}}}; if (eof()){print "$counter\n"')")
	fi
	if [ "$mode" == "split" ]
	then
		paste <(sha256sum $f) <(echo -e "$l\t$m\t$(cat <(echo -e "$l\t$m") $f | perl -ne 'chomp; if ($. == 1){@a=split("\t"); $cutoff=$a[0]; $minlen=$a[-1]; $counter=1; open(FH, ">", sprintf("%04d", $counter).".fasta")}else{if ($_ =~ /^>/){if ($. > 2){if ($length >= $minlen){$cum_length+=$length; print FH "$header\n$seq\n"; $header = $_; $seq = ""; if ($cum_length >= $cutoff){close FH; $counter++; open(FH, ">", sprintf("%04d", $counter).".fasta"); $cum_length=0; }}}; $header = $_; $seq = ""; $length = 0}else{$length+=length($_); $seq.=$_}}}; if (eof()){print "$counter\n"; if ($length >= $minlen){print FH "$header\n$seq\n"}')")
	fi
fi

#cat <(echo -e ">\t$l\t$m") <(zcat $f) | perl -ne 'if ($_ =~ /^>/){$header = $_; $seq = ""; if ($. > 1){if ($length >= $minlen){$cum_length+=$length; print FH "$header\n$seq\n"} if ($cum_length >= $cutoff){$counter++; close FH; open(FH, '>', $counter.".fasta"); $cum_length=0}}else{chomp; @a=split("\t"); $cutoff=$a[-2]; $minlen=$a[-1]}; $length = 0}else{$length+=(length($_)-1); $seq+=$_}; if (eof()){$counter++; print "$counter\n"}'
