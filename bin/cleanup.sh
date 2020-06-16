#!/bin/bash

dir=$1

echo -e "\n$(date)\tStarting ...\n"

echo -e "[$(date)]\t$dir -> $dir.tar.gz"
tar cfz $dir.tar.gz $dir
if [ $? -eq 0 ]
then
	rm -rf $dir
else
	echo -e "Some problem with $dir"
fi

echo -e "\n$(date)\tFinished!\n"

