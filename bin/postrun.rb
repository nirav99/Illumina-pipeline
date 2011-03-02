#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'PipelineHelper'
require 'EmailHelper'

# This postrun is automatically called by CASAVA after sequences are generated.
# We upload the Summary.htm to LIMS, send it via email to recepients, start the
# uniqueness analysis and start BWA alignment.

# Method to send the Summary.htm as an email attachment
def emailSummaryHTML(fcBarcode)
  attachFile = "Summary.htm"
  currDir    = `pwd`
  bodyText   = "The path to the summary file is " + currDir
  subject    = "Illumina Lane Summary : " + fcBarcode.to_s
  emailFrom  = "sol-pipe@bcm.edu"  
  obj        = EmailHelper.new()
  emailTo    = obj.getResultRecepientEmailList()

  puts "Sending Summary.htm via email..."
  obj.sendEmailWithAttachment(emailFrom, emailTo, subject, bodyText, attachFile)
  puts "Completed"
end

helper = PipelineHelper.new()
fcName = helper.findFCName()
puts "Flowcell Name : " + fcName
lanes  = helper.findAnalysisLaneNumbers()
puts "Analysis Lane Number : " + lanes.to_s
fcBarCode = fcName + "-" + lanes.to_s

#Upload HTML summary to LIMS
uploadLIMSHTMLCmd = "ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/upload_LIMS_summary.rb"
output = `#{uploadLIMSHTMLCmd}`
puts output

# Email the Summary.htm file
emailSummaryHTML(fcBarCode)

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
