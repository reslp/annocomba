#!/bin/bash

dirname=$1

if [ -z $2 ]
then
	mode="tar"
else
	mode=$2
fi

echo -e "[$(date)] - to archive: $dirname"

if [[ "$mode" = "tar" || "$mode" = "tar.gz" || "$mode" = "zip" ]]
then
	echo -e "[$(date)] - archive mode: $mode\n"
else
	echo -e "[$(date)] - only know archive modes 'tar', 'tar.gz' or 'zip' - try again"
	exit
fi

if [ $mode = "tar" ]
then
	archive="$dirname.tar"
	tar cf $archive $dirname
fi

if [ $mode = "tar.gz" ]
then
	archive="$dirname.tar.gz"
	tar cfz $archive $dirname
fi

if [ $mode = "zip" ]
then
	archive="$dirname.zip"
	zip -q -r $archive $dirname
fi

if [[ $? -eq 0 ]]
then
	echo "[$(date)] - All good - archived to: $archive"
	find $dirname | sort > $dirname.content.txt
	tree $dirname --filesfirst > $dirname.tree.txt
	if [[ $? -eq 0 ]]
	then
		echo -e "[$(date)] - content in $dirname.content.txt"
		echo -e "[$(date)] - tree in $dirname.tree.txt"
		echo -e "[$(date)] - removing original"
		rm -rf $dirname
		echo -e "[$(date)] - calculating md5sum of $archive > $archive.md5sum.txt"
		md5sum $archive > $archive.md5sum.txt
		echo -e "[$(date)] - Done!"
	else
		echo -e "[$(date)] - something went wrong with recording the content"
	fi
else
	echo -e "[$(date)] - something went wrong during archiving"
fi

