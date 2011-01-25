#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'PipelineHelper'

# This is a new post run script that does not copy files to the mini analysis
# directory. It maps the sequence files using BWA aligner.

helper = PipelineHelper.new()
fcName = helper.findFCName()
puts "Flowcell Name : " + fcName
lanes  = helper.findAnalysisLaneNumbers()
puts "Analysis Lane Number : " + lanes.to_s
fcBarCode = fcName + "_" + lanes.to_s

#Upload HTML summary to LIMS
uploadLIMSHTMLCmd = "ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/upload_LIMS_summary.rb"
output = `#{uploadLIMSHTMLCmd}`
puts output

# Email the Summary.htm file
emailHTMLsummaryCmd = "sh /stornext/snfs5/next-gen/Illumina/ipipe/bin/email_analysis_summary.sh"
output = `#{emailHTMLsummaryCmd}`
puts output

# Map sequence files using BWA
bwaCmd = "ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/bwa_bam.rb"
output = `#{bwaCmd}`
puts output

# Run uniqueness analysis
uniqCmd = "ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/FindUniqReads.rb"
sch1 = Scheduler.new(fcBarCode + "_Uniqueness", uniqCmd)
sch1.setMemory(8000)
sch1.setNodeCores(1)
sch1.setPriority("normal")
sch1.runCommand()
uniqJobName = sch1.getJobName()

puts "Successfully Completed. Terminating."
