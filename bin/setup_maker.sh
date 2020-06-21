#!/bin/bash

#use as ./setup_maker.sh external/maker-2.31.10.tgz destination/

makertarball=$1
destination=$2


#build maker
tar xfz $makertarball -C $destination
cd $destination/maker/src && perl Build.PL && ./Build install && cd ../../../
export PATH="$(pwd)/$destination/maker/bin:${PATH}"

maker -v
#maker -CTL
