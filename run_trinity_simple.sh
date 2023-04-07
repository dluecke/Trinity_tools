#!/bin/bash

# run_trinity_simple.sh runs a basic trinity assembly from a prewritten samples file.  
# can use make_samples_file.sh to write samples file from lists of file paths

if [[ $1 != *".tsv" ]]; then
	echo "USAGE: $0 <SAMPLES.tsv> <path/to/EFCE>"
	exit 1

fi

if [ ! -d $2 ]; then
	echo "USAGE: $0 <SAMPLES.tsv> <path/to/EFCE>"
	exit 1

fi

if [[ $1 == *"-samples"* ]]; then
	jobnamestub=$(basename $1 | cut -d'-' -f1)
else
	jobnamestub=$(basename $1 | cut -d'.' -f1)
fi

jobname="Trinity_$jobnamestub"

#cp $2/Trinity_scripts/Trinity_TEMPLATE.sb ./$jobname.sb
cp $2/slurm_scripts/TEMPLATE-Trinity_ExpressionFilter.sb ./$jobname.sb

sed -i 's/JOBNAME/'$jobname'/g' $jobname.sb
sed -i 's/SAMPLESFILE/'$1'/g' $jobname.sb
# use @ for file path substitution 
sed -i 's@EFCE@'$2'@g' $jobname.sb

echo "SLURM submission script written: "$jobname".sb"
cat $jobname.sb
echo

echo
echo ------------------------------------------------
echo "Will run Trinity assembly in $PWD"
echo "By default will automatically delete read_partitions directory to save space, edit SLURM submission file to preserve this directory"
while read -p "Do you want to submit to SLURM? (y/n): "; do
	case $REPLY in
		y) 
			sbatch $jobname.sb
			;;
		*)
			echo "Not submitting now, can submit with sbatch when ready"
			;;
	esac
	break
done