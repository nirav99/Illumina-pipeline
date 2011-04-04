#!/usr/bin/sh

echo "Starting shell script"
source /users/p-illumina/.bashrc
echo "Done source .bashrc"

echo "Starting Ruby startAnalysis_wip"
ruby /stornext/snfs5/next-gen/Illumina/ipipe/helpers/startAnalysis.rb >> /stornext/snfs5/next-gen/Illumina/ipipe/helpers/flowcell_start.log
echo "DONE"
