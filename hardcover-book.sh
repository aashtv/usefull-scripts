#!/bin/sh

# by Andrey Shitov (aa.shtv@gmail.com)
# Requires: psutils, ghostscript-core [, poppler-utils]

if [ -z "$1" ] 
then
	echo Usage: $0 SOURCE
	exit
fi

if [ ! `command -v psselect` ]; then needpackage=" * PostScript utilites (psselect, psnup, psbook)\n"; fi
if [ ! `command -v gs` ]; then needpackage="${needpackage} * Ghostscript core (gs)\n"; fi
if  [ ! -z "$needpackage" ]
then
	echo -e "Missing dependencies:\n${needpackage}Install needed packages and try again"
	exit 1
fi

source="${1}"
output=${source##*/}
output="${output%%.ps}.print.ps"

if [ ! -f "$source" ]
then 
	echo -e "File \"$source\" does not exists"
	exit 1
fi

tmp=`mktemp -d`

if [[ `file -ib "$source"` = "application/pdf"* ]]
then
	if [ ! `command -v pdftops` ]
	then
		echo -e "Seems pdftops is not installed in your system.\nInstall pdftops or convert \"$source\" to PostScript manualy and try again."
		exit 1
	fi
	pdftops "$source" ${tmp}/source.ps
	source=${tmp}/source.ps
elif [[ ! `file -ib "$source"` = "application/postscript"* ]]
then
	echo "Only PDF and PostScript files are supported"
	rm -rf $tmp
	exit 1
fi

pagesOnList=4
listInStack=8
let "pagesInStack=$pagesOnList * $listInStack"

pagesInBook=`grep showpage "$source" | wc -l`

let "b=1"
# split book to stacks
while [ $b -le $pagesInBook ]
do
	if [ $b -eq $pagesInBook ]
	then psselect -p${b} "$source" ${b}.ps
	else psselect -p${b}-$(($b-1+$pagesInStack)) "$source" ${tmp}/`date +%s%N`.ps
	fi
	let "b=$b+$pagesInStack"
done
if [ -f $tmp/source.ps ]; then rm -f $tmp/source.ps; fi
#sort pages in stack
for file in ${tmp}/*.ps; 
do
	psbook $file ${file}.sorted.ps
	rm $file -f
done

#place 2 pages in one A4
let "b=1"
for file in ${tmp}/*.sorted.ps;
do
	psnup -Pa4 -2 $file ${tmp}/`printf "%05d" $b`.ps
	rm $file -f
	let "b=$b+1"
done

# We don't wan't to overwrite the existing files
let "b=1"
while [ -f "${output}" ]
do
	output="${source%%.ps}.print (${b}).ps"
	let "b=$b+1"
done


merge=
for file in ${tmp}/*.ps;
do
	merge="$merge $file"
done
gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sPAPERSIZE=a4 -sOutputFile="$output" $merge

if [ $? -eq 0 ];
then
	echo -e "${output}\nDone."
fi

rm $tmp -rf
