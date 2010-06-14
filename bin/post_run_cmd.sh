#!/bin/bash

# Script to run as POST_RUN_COMMAND at the end of GERALD analysis
# 1) It emails Summary.htm as email 
# 2) It uploads Summary.htm to LIMS
# 3) It uploads results from Summary.xml to LIMS
# 4) It copies files in mini analysis

#TODO: Catch errors and report them

# Send Summary.htm as an email attachment
sh /stornext/snfs5/next-gen/Illumina/ipipe/bin/email_analysis_summary.sh

# Upload analysis results to LIMS
ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/upload_LIMS_results.rb

# Upload Summary.htm to LIMS
ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/upload_LIMS_summary.rb

# Run uniqueness analysis
bsub -J "Uniqueness_analysis" -o u.o -e u.e -q "normal" -n 1 -R "rusage[mem=4000]span[hosts=1]" ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/FindUniqReads.rb

# Start mini-analysis
bsub -J "mini_analysis" -o m.o -e m.e -q "normal" -n 1 -R "rusage[mem=1000]span[hosts=1]" ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/miniAnalysis.rb
