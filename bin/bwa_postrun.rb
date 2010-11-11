#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'PipelineHelper'

# This script is run after BWA alignment completes.

# Upload results to LIMS
uploadLIMSResultsCmd = "ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/upload_LIMS_results.rb"
output = `#{uploadLIMSResultsCmd}`
puts output

# Appropriate code can be added here to clean up the GERALD directory of
# unwanted files such as .sam, intermediate .bam files, .sai files etc.
