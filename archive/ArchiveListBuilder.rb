#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "third_party")
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'EmailHelper'

# This script queries LIMS to find the list of all the results paths uploaded to
# LIMS for a specific day. Current delay is 2 days. It appends a list of these 
# directories to a log file which can be periodically archived.
# Author : Nirav Shah niravs@bcm.edu

# Class to build a list of directories to archive
class ArchiveListBuilder
  def initialize()
    @limsScript = File.join(File.dirname(__FILE__), ".", "..", "third_party")
    @limsScript = @limsScript + "/getResultsPathInfo.pl"

    @archiveLogFileName = File.dirname(__FILE__) + "/archive_request_list.txt"

    @dateOfInterest = getPreviousDate()
    runLIMSQuery()
  end

private 
  # Using the current time, obtain the date for the previous day
  def getPreviousDate()
    time = Time.new
    
    #Substract 172800 from time to get date 2 days ago
    time = time - 172800 
    ascTime = time.strftime("%Y-%m-%d")
    return ascTime
  end

  # Query the LIMS for result paths
  def runLIMSQuery()
    archiveCommand = "perl " + @limsScript + " " + @dateOfInterest.to_s
    output = `#{archiveCommand}`

    if output.match(/[Ee]rror/)
      puts "Error in obtaining result paths"
      handleError(output)
    else
      buildArchiveList(output)
    end
  end

  # Append the list of result paths to the log file
  def buildArchiveList(limsOutput)
    begin
      fileHandle = File.open(@archiveLogFileName, "a")

      limsOutput.each do |record|
        record.strip!
        tokens       = record.split(";")
        dirToArchive = tokens[1].to_s  
        fileHandle.puts dirToArchive.to_s
      end
      fileHandle.close()
    rescue Exception => e
      errorMessage = e.message + " " + e.backtrace.inspect
      puts "Error : " + errorMessage.to_s
      handleError(errorMessage)
    end
  end  

  # Handling error - for now email the error message
  def handleError(errorMsg)
    emailErrorMessage(errorMsg)
  end

  # Send email describing the error message to interested watchers
  def emailErrorMessage(msg)
    obj          = EmailHelper.new()
    emailFrom    = "sol-pipe@bcm.edu"
    emailTo      = obj.getErrorRecepientEmailList()
    emailSubject = "Archive Script : Error encountered in obtaining directory paths for date : " + 
                   @dateOfInterest.to_s
    emailText    = msg

    obj.sendEmail(emailFrom, emailTo, emailSubject, emailText)
  end
end

obj = ArchiveListBuilder.new()
