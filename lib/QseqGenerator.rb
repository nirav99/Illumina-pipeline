#!/usr/bin/ruby
$:.unshift File.dirname(__FILE__)

require 'fileutils'
require 'PipelineHelper'
require 'Scheduler'
require 'FlowcellDefinitionBuilder'
require 'EmailHelper'

# Class to generate qseq files in the base calls directory
# Author: Nirav Shah niravs@bcm.edu

class QseqGenerator

  # Class constructor - to prepare base calls directory to generate qseq
  def initialize(flowcellName)
    begin
      initializeDefaultParams(flowcellName)
      exitStatus = runBclToQseqCommand() 

      if exitStatus != 0
        raise "Bcl to qseq command failed"
      end

      # Bcl to qseq generator passed. Switch to basecalls directory of the
      # flowcell and run make from there.

      currDir = FileUtils.pwd()
      FileUtils.cd(@baseCallsDir)
      runMake()
      FileUtils.cd(currDir)

      puts "Creating flowcell definition XML"
      createFlowcellDefinitionXML()
      puts "Finished writing flowcell definition XML"
      puts "Uploading analysis start date"
      uploadAnalysisStartDate()
      
      puts "Invoking command to split qseq files"
      # Added functionality to split qseq files
      splitQseqFiles()
    rescue Exception => e
      $stderr.puts e.message
      $stderr.puts e.backtrace.inspect
      handleError(e.message)
    end
  end

  private

  # Initialize the class members required for other methods
  def initializeDefaultParams(flowcellName)
    @fcName       = flowcellName
    @pHelper      = PipelineHelper.new
    @baseCallsDir = @pHelper.findBaseCallsDir(@fcName)
    @intensityDir = @baseCallsDir.gsub(/\/[a-zA-Z0-9_]+$/, "")
    @priority     = "high"

    if @fcName == nil || @fcName.eql?("")
      raise "Flowcell name is null or empty"
    end
  end

  # Method to prepare environment for Illumina's bcl to qseq generator to
  # execute
  def runBclToQseqCommand()
    scriptName = "/stornext/snfs5/next-gen/Illumina/OLB1.9/OLB1.9/" +
                  "OLB-1.9.0/bin/setupBclToQseq.py"

    # Build the command to generate qseq files 
    cmd = scriptName + " -b " + @baseCallsDir + " -o " + @baseCallsDir +
          " --overwrite  --in-place --ignore-missing-bcl --ignore-missing-stats" 

    # Add -P .clocs only to the sequencers running RTA 1.12
    if !@fcName.match(/EAS376/) && !@fcName.match(/EAS034/)
      cmd = cmd + " -P .clocs"
    else
      cmd = cmd + " -p " + File.dirname(File.expand_path(@baseCallsDir)) + "/L00*"
    end
    puts "Executing command : "
    puts cmd.to_s
    
    output = `#{cmd}`
    exitStatus = $?
    puts "Exit Status : " + exitStatus.to_s
    puts output
    return exitStatus
  end

  # Method to run "make" command on the cluster
  # This generates qseq files.
  def runMake()
    puts "Running make command to generate qseq files"
    s = Scheduler.new(@fcName + "_Generate_Qseq", "make -j8")
    s.setMemory(28000)
    s.setNodeCores(7)
    s.setPriority(@priority)
    s.runCommand()
    @qseqGenerationJobName = s.getJobName()
    puts "Qseq Generation Job Name = " + @qseqGenerationJobName.to_s
  end

  # Helper method to upload analysis start date to LIMS for tracking purposes
  def uploadAnalysisStartDate()
    fcNameForLIMS = @pHelper.formatFlowcellNameForLIMS(@fcName)

   puts "FC name for lims : " + fcNameForLIMS.to_s

   limsScript = File.dirname(File.dirname(File.expand_path(__FILE__))) +
               "/third_party/setFlowCellAnalysisStartDate.pl" 

    uploadCmd = "perl " + limsScript + " " + fcNameForLIMS
    puts "Analysis start date upload command : " + uploadCmd.to_s

    output = `#{uploadCmd}`

    puts "Output from LIMS : " + output.to_s
   
    if output.match(/[Ee]rror/)
      puts "Error in uploading Analysis Start Date to LIMS"
    else
      puts "Successfully uploaded Analysis Start Date to LIMS"
    end
  end

  # Contact LIMS and write an XML file having necessary information to start the
  # analysis. This is a temporary functionality until LIMS can provide this XML.
  def createFlowcellDefinitionXML()
    obj = FlowcellDefinitionBuilder.new(@fcName, @baseCallsDir)
  end

  # For a multiplexed flowcell, the qseq files have to be split based on the
  # barcode information. This method achieves that through the supporting
  # script.
  # If this flowcell is not multiplexed, the supporting script will simply
  # return without attempting to split any qseq files.
  def splitQseqFiles()
    splitCmd = "ruby " + File.dirname(File.expand_path(__FILE__)) + 
               "/QseqSplitter.rb " + @fcName.to_s
    puts "Command to split qseq files : " + splitCmd

    s = Scheduler.new(@fcName + "_Split_Qseq", splitCmd)
    s.setMemory(2000)
    s.setNodeCores(1)
    s.setPriority(@priority)
    s.setDependency(@qseqGenerationJobName.to_s)
    s.runCommand()
    @splitQseqJobName = s.getJobName()
    puts "Splitting Qseq Job Name  = " + @splitQseqJobName.to_s
  end

  # Method to handle error
  def handleError(errorMsg)
   puts "Error encountered. Message : \r\n" + errorMsg
   emailErrorMessage(errorMsg)
   puts "Aborting execution\r\n"
   exit -4
 end

  # Send email describing the error message to interested watchers
  def emailErrorMessage(msg)
    obj          = EmailHelper.new()
    emailFrom    = "sol-pipe@bcm.edu"
    emailTo      = obj.getErrorRecepientEmailList()
    emailSubject = "Error in demultiplexing flowcell " + @fcName.to_s
    emailText    = msg

    obj.sendEmail(emailFrom, emailTo, emailSubject, emailText)
  end
end

flowcellName = ARGV[0]
obj = QseqGenerator.new(flowcellName)
