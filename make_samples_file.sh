#!/bin/bash

# make_samples_file.sh writes a sample file for Trinity 
# adapted from run_trinity.sh
# can add to existing samples file if file names have tissue in different position or different delimiter 
# some final editing in nano may be required

function usage() {
	echo "USAGE: $0 [-t NUMERIC position in file name for sample type -d 'DELIMITER' (default '_') -p NUMERIC (default 1) if tissue string has '.' this is which field(s) to include]  <FILES.fofn> <OUTPUT_FILE.tsv>"
}

tsvout=${@: -1}
fofn=${@: -2:1}

if [[ "$#" == 0 ]]; then
	usage
	echo "no args"
	exit 1
fi

if [[ $fofn != *".fofn" ]]; then
	usage
	echo "no fofn"
	exit 1
fi

if [[ $tsvout != *".tsv" ]]; then
	usage
	echo "no tsv"
	exit 1
fi

delim='_'
period_position=1

while getopts ":d:t:p:" opt; do
	case $opt in
		d)
			delim=$OPTARG
			;;
		t)
			type_position=$OPTARG
			;;
		p)
			period_position=$OPTARG
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			usage
			exit 1
			;;
	esac
done

if [[ -z $type_position ]]; then
	usage
	echo "need to set -t"
	exit 1
fi

if [[ $type_position -ge 0 ]]; then
	echo "position in file name of sample type: "$type_position
else
	usage
	echo "-t must be integer"
	exit 1
fi

if grep -q $delim"R2" $fofn; then
	PAIRED=1
	echo "Found R2 files, treating as paired end"
else
	PAIRED=0
	echo "No R2 files, treating as single end"
fi
echo "-------------------"

if [ $PAIRED == 1 ]; then
	grep $delim"R1" $fofn > temp_new_R1.fofn
else
	cat $fofn > temp_new_R1.fofn
fi

# getting info from previous samples file if it exists
if [ -f $tsvout ]; then
	echo "Appending to existing samples file"
	cut -f3 $tsvout > temp_old_R1.fofn
	cut $tsvout -f1 | tr '[:lower:]' '[:upper:]' > temp_old_tissues.txt
	cut $tsvout -f1 | sort | uniq -c > temp_old_samplecounts.tsv
else
	echo "Writing new samples file"
	touch temp_old_R1.fofn temp_old_tissues.txt temp_old_samplecounts.tsv
fi
echo "-------------------"

# getting tissue information from new file names
rev temp_new_R1.fofn | cut -d'/' -f1 | rev | cut -d$delim -f$type_position | cut -d'.' -f$period_position | tr '[:lower:]' '[:upper:]' > temp_new_tissues.txt
rev temp_new_R1.fofn | cut -d'/' -f1 | rev | cut -d$delim -f$type_position | cut -d'.' -f$period_position | sort | uniq -c > temp_new_samplecounts.tsv

# combining all tissue information and file names
cat temp_old_tissues.txt temp_new_tissues.txt > temp_tissues.txt
sort temp_tissues.txt | uniq -c > temp_samplecounts.tsv
cat temp_old_R1.fofn temp_new_R1.fofn > temp_R1.fofn

echo samples and replicate counts:
cat temp_samplecounts.tsv
echo

while read line; do
	# iterating through samplescounts file, first get the total number and tissue types
	count=$(echo $line | cut -d' ' -f1)
	tissue=$(echo $line | cut -d' ' -f2)
	
	# want to start the reps count after any previously written lines for that tissue
	priorcount=$(grep $tissue temp_old_samplecounts.tsv | sed 's@^[^0-9]*\([0-9]\+\).*@\1@')
	startcount=$((priorcount + 1))
	
	for i in $(seq $startcount $count); do
		R1path=$(awk -F"/" -v tissue="$delim$tissue$delim" 'toupper($NF) ~ tissue' temp_R1.fofn | sed -n "$i"p) # use awk to only match file name (last field $NF when "/" separated)
		R2path=$(echo $R1path | sed 's/'$delim'R1/'$delim'R2/g')
		if [ $PAIRED == 1 ]; then
			echo -e $tissue'\t'$tissue"_rep$i"'\t'$R1path'\t'$R2path
		else
			echo -e $tissue'\t'$tissue"_rep$i"'\t'$R1path
		fi
	done
done < temp_samplecounts.tsv >> $tsvout

echo "Samples file $tsvout written, checking all paths can be found:"
for i in $(cut -f3 $tsvout); do ls $i; done
for i in $(cut -f4 $tsvout); do ls $i; done

rm temp_*