#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'rubygems'
require 'hpricot'
require 'PipelineHelper'
require 'FCBarcodeFinder'
require 'EmailHelper'

# Class to upload the Summary.htm files to LIMS
# This script should be executed from the same directory containing
# the GERALD analysis results

class UploadHTMLSummary
  def initialize()
    @currentDir = Dir.pwd
    @lanes      = ""
    @fcName     = ""
    @limsScript = "/stornext/snfs5/next-gen/Illumina/ipipe/third_party/" + 
                  "uploadHtmlSummary.pl"
    @errorFound = false
    @helper     = PipelineHelper.new()

    @limsBarcode = ""
    obj = FCBarcodeFinder.new
    @limsBarcode = obj.getBarcodeForLIMS()

    if !File.exists?("Summary.xml")
      handleMissingFileError("Summary.xml")
    end

    if !File.exists?("Summary.htm")
      handleMissingFileError("Summary.htm")
    end

    if !File.exists?("config.txt")
      handleMissingFileError("config.txt")
    end
    @lanes  = @helper.findAnalysisLaneNumbers()
    @fcName = @helper.findFCName()

    if @lanes == nil || @lanes == ""
      handleError("Did not find valid analysis lane numbers in config.txt")
    end

    if @fcName == nil || @fcName == ""
      handleError("Did not find valid flowcell name")
    end
  end

  # Method to build the LIMS command to upload Summary.htm file
  def uploadSummaryToLIMS()
    #@lanes.each_byte do |lane|
      cmd = "perl " + @limsScript + " " + @limsBarcode + " Summary.htm"
      puts cmd
      output = `#{cmd}`
      output.downcase!
      exitStatus = $?

# Current behavior of perl wrapper to LIMS to is return zero
# with the error message Error: Cannot connect. If either of 
# these conditions occur, consider it as an error
# As of April 19, 2010, I stopped considering value of exitStatus
# since the perl script returns zero for both error and success
# scenarios
      if output.match(/error/)  #|| exitStatus == 0  
#         ( output <=> "htmlsummary file has been saved" ) != 0
        @errorFound = true
        handleLIMSUploadError(cmd)
      end
    #end

    # If all Summary files were successfully uploaded, exit with 
    # return code zero.
    if @errorFound == false
      puts "No error found. Exiting with return code 0"
      exit 0
    end
  end

  private

  # Method to appropriately handle the error if connection to LIMS
  # failed
  def handleLIMSUploadError(cmd)
    puts "Error : Could not upload Summary file to LIMS"

    obj          = EmailHelper.new()
    emailFrom    = "sol-pipe@bcm.edu"
    emailTo      = obj.getErrorRecepientEmailList()
    emailSubject = "Error in uploading Summary file to LIMS"
    emailText    = "Summary.htm could not be uploaded to LIMS. Cmd used was : " +
                   cmd
    obj.sendEmail(emailFrom, emailTo, emailSubject, emailText)
    exit -1
  end

  def handleMissingFileError(fileName)
    puts "Error : Missing File : " + fileName 
    puts "Current Directory : " + Dir.pwd
    exit -2
  end

  def handleError(errMsg)
    puts "Error encountered : " + errMsg
    exit -2
  end
end

obj = UploadHTMLSummary.new()
obj.uploadSummaryToLIMS()
