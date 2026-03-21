#!/bin/bash


. /opt/Xilinx/14.7/ISE_DS/settings64.sh

for i in petio ; do

	if test $i/work/*.bit -nt $i.bin ; then 
		echo "make it"
		promgen -spi -p bin -w -u 0 $i/work/*.bit -o $i.bin
	fi;
done;

