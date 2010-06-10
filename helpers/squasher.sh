#!/bin/sh
#
# $Id: squasher.sh 490 2008-04-16 21:50:04Z dc12 $
#
# squasher.sh:
#		Use this script to create the splits and squashs files when you are in ref
#		dir entry. Ref's dir entries look like:
#		$ ls
#		./original/ <- Original references in here
#		
DEBUG=0
#dataSolexa="/data/slx/USI-EAS09/GAPipeline"
dataSolexa="/stornext/snfs5/next-gen/Illumina/GAPipeline/current"
solPipeDir="$dataSolexa"
externalScripts="/stornext/snfs5/next-gen/Illumina/ipipe/helpers"
plit="$externalScripts/splitFAxN.pl"

error() 
{
	echo $1
	exit
}

run() {
	if [ $DEBUG == "1" ]
	then
		echo $1
	else
		$1
	fi
}

while getopts ":d" opt; do
  someOpts="true"
  case $opt in
    d)  DEBUG=1 ;;
    h)  usage ;;
    \?) usage ;;
    *) usage ;;
  esac
done

shift $(($OPTIND - 1))
references="$*"

# are we in a reference dir entry?
if [ ! -d ./original ] 
then
	error "This is not a reference entry dir."
fi

# Do we have originals to work with?
[ `find ./original -type f | wc -l` == "0" ] && error "No original files detected."

# Create splits
echo "Splitting..."
run "mkdir -p ./split"
for i in `find ./original -type f`
do
	b=`basename $i`
	run "perl $plit ./original/$b ./split/${b}.split.fa"
done

# Create squashs
echo "Squashing..."
run "mkdir -p ./squash"
for i in `find ./original -type f`
do
#	run "$solPipeDir/Eland/squashGenome ./squash $i"
        run "$solPipeDir/bin/squashGenome ./squash $i"
done
