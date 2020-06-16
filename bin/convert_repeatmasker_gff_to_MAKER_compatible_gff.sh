#!/bin/bash

cat $1 | \
grep -v -e "Satellite" -e ")n" -e "-rich" | perl -ne '$id; if(!/^\#/){chomp; $_ =~ s/\r//g; $id++; print "$_;ID=$id\n"}else{print "$_"}'
