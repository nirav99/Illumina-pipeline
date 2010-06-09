#!/usr/bin/ruby
require 'rubygems'
require 'hpricot'
require 'fileutils'
require 'net/smtp'

# This class encapsulates common routines required by other 
# pipeline scripts
class PipelineHelper

  # Method to read config.txt and return lanes for which
  # analysis was performed
  def findAnalysisLaneNumbers()
    analysisLanes = ""
    configFileLines = IO.readlines("config.txt")
    idx=0

    while idx < configFileLines.size do
      if ( configFileLines[idx] =~ /^[1-8]+:ANALYSIS/) &&
         !(configFileLines[idx] =~ /none/) then
        temp = configFileLines[idx].index(":") - 1
        analysisLanes = configFileLines[idx][0..temp]
      end
      idx += 1
    end
    return analysisLanes
  end

  # Method to find flowcell name from Summary.xml
  def findFCName()
    doc = Hpricot::XML(open('Summary.xml'))
    fcName = ""
    (doc/:'ChipSummary').each do|summary|
      runFolder = (summary/'RunFolder').inner_html
      run = runFolder[/FC(.+)$/]
      if run == nil
         run = runFolder[/([a-zA-Z0-9]+)$/]
         fcName = run
      else
        fcName = run.slice(2,run.size)
      end
    end
    return fcName
  end

  # Method to send an email
  # Parameter "to" is an array of email addresses separated by commas
  def sendEmail(from, to, subject, message)
     toMail = ""
     to.each { |x| toMail= toMail + ",#{x}" }

msg = <<END_OF_MESSAGE
From: <#{from}>
To: <#{toMail}>
Subject: #{subject}

#{message}
END_OF_MESSAGE

      Net::SMTP.start('smtp.bcm.tmc.edu') do |smtp|
      smtp.send_message msg, from, to
    end
  end
end

