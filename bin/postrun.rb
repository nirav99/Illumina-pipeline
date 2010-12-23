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
sch1 = Scheduler.new("Uniqueness_" + fcBarCode, uniqCmd)
sch1.setMemory(8000)
sch1.setNodeCores(1)
sch1.setPriority("normal")
sch1.runCommand()
uniqJobName = sch1.getJobName()

=begin
# Zip sequence files
zipSeqCmd = "bzip2 *sequence.txt"
sch2 = Scheduler.new("Zip_sequence_" + fcBarCode, zipSeqCmd)
sch2.setMemory(4000)
sch2.setNodeCores(1)
sch2.setPriority("normal")
sch2.setDependency(uniqJobName)
sch2.runCommand()

# Zip export files
zipExpCmd = "bzip2 *export.txt"
sch3 = Scheduler.new("Zip_export_" + fcBarCode, zipExpCmd)
sch3.setMemory(4000)
sch3.setNodeCores(1)
sch3.setPriority("normal")
# No need to include dependency on uniqueness here
sch3.runCommand()

# Delete unwanted and large files from the GERALD directory
rmAnomalyCmd = "rm *_anomaly.txt"
rmReanomrowCmd = "rm *_reanomraw.txt"

puts "Deleting large unused files"

`#{rmAnomalyCmd}`
`#{rmReanomrowCmd}`

puts "Large unused files deleted"
=end

puts "Successfully Completed. Terminating."
