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

class UploadMapStatsFile
  def initialize()
    @currentDir   = Dir.pwd
    @lanes        = ""
    @fcName       = ""
    @limsScript   = "/stornext/snfs5/next-gen/Illumina/ipipe/third_party/" + 
                    "uploadBAMAnalyzerFile.pl"
    @errorFound   = false
    @helper       = PipelineHelper.new()
    @fileToUpload = "BWA_Map_Stats.txt"

    @limsBarcode = ""
    obj = FCBarcodeFinder.new
    @limsBarcode = obj.getBarcodeForLIMS()

    if !File.exists?(@fileToUpload)
      handleMissingFile(@fileToUpload)
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
  def uploadFileToLIMS()
      cmd = "perl " + @limsScript + " " + @limsBarcode + " " + @fileToUpload
      puts cmd
      output = `#{cmd}`
      output.downcase!
      exitStatus = $?

      if !output.match(/bamanalyzer file has been saved/)  #|| exitStatus == 0  
#         ( output <=> "htmlsummary file has been saved" ) != 0
        @errorFound = true
        handleLIMSUploadError(cmd)
      else
        puts "LIMS acknowledged uploading the file : " + @fileToUpload
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
    puts "Error : Could not upload " + @fileToUpload + " to LIMS"

    obj          = EmailHelper.new()
    emailFrom    = "sol-pipe@bcm.edu"
    emailTo      = obj.getErrorRecepientEmailList()
    emailSubject = "Error in uploading file " + @fileToUpload + " to LIMS"
    emailText    = @fileToUpload + " could not be uploaded to LIMS. Cmd used was : " +
                   cmd
    obj.sendEmail(emailFrom, emailTo, emailSubject, emailText)
  end

  def handleMissingFile(fileName)
    puts "Error : Missing File : " + fileName 
    puts "Current Directory : " + Dir.pwd
    exit 0
  end

  def handleError(errMsg)
    puts "Error encountered : " + errMsg
  end
end

obj = UploadMapStatsFile.new()
obj.uploadFileToLIMS()
