#!/bin/bash

# Script to run as POST_RUN_COMMAND at the end of GERALD analysis
# 1) It emails Summary.htm as email 
# 2) It uploads Summary.htm to LIMS
# 3) It uploads results from Summary.xml to LIMS
# 4) It copies files in mini analysis

#TODO: Catch errors and report them

ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/PhixFilter.rb
# Send Summary.htm as an email attachment
sh /stornext/snfs5/next-gen/Illumina/ipipe/bin/email_analysis_summary.sh

# Upload analysis results to LIMS
ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/upload_LIMS_results.rb

# Upload Summary.htm to LIMS
ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/upload_LIMS_summary.rb

# Run uniqueness analysis
echo "ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/FindUniqReads.rb" | msub -N "Uniqueness_analysis" -q normal -d `pwd` -e u.e -o u.o -l nodes=1:ppn=1,mem=8000mb -V

# Start mini-analysis
#echo "ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/miniAnalysis.rb" | msub -N "mini_analysis" -q normal -d `pwd` -e m.e -o m.o -l nodes=1:ppn=1,mem=2000mb -V
