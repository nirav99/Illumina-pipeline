#!/usr/bin/ruby
$:.unshift File.dirname(__FILE__)

require 'fileutils'
require 'PipelineHelper'
require 'Scheduler'
require 'FlowcellDefinitionBuilder'

# Class to generate qseq files in the base calls directory
class QseqGenerator

  # Class constructor - to prepare base calls directory to generate qseq
  def initialize(flowcellName)
    @scriptName = "/stornext/snfs5/next-gen/Illumina/OLB1.9/OLB1.9/" +
                  "OLB-1.9.0/bin/setupBclToQseq.py"

    @fcName = flowcellName
    @priority = "high" # Allowed values are normal / high for the scheduling
                       # queue

    if @fcName == nil || @fcName.eql?("")
      raise "Flowcell name is null or empty"
    end

    @pHelper = PipelineHelper.new
    @baseCallsDir = @pHelper.findBaseCallsDir(@fcName)
    @intensityDir = @baseCallsDir.gsub(/\/[a-zA-Z0-9_]+$/, "")

    # Build the command to generate qseq files 
    cmd = @scriptName + " -b " + @baseCallsDir + " -o " + @baseCallsDir +
          " --overwrite  --in-place --ignore-missing-bcl --ignore-missing-stats" 

   # Add -P .clocs only to the sequencers running RTA 1.12
   if !flowcellName.match(/EAS376/) && !flowcellName.match(/EAS034/)
      cmd = cmd + " -P .clocs"
   else
     cmd = cmd + " -p ../L00*"
   end

    puts "Executing command : "
    puts cmd.to_s
    
    output = `#{cmd}`
    exitStatus = $?
    puts "Exit Status : " + exitStatus.to_s
    puts output

    if exitStatus != 0
      raise "Error in generating qseq files : " + output
    else
      currDir = FileUtils.pwd()
      FileUtils.cd(@baseCallsDir)
      runMake()
      FileUtils.cd(currDir)
    end
  end

  private
  # Method to run "make" command on the cluster
  # This generates qseq files.
  def runMake()
    puts "Running make command to generate qseq files"
    s = Scheduler.new(@fcName + "_Generate_Qseq", "make -j8")
    s.setMemory(28000)
    s.setNodeCores(6)
    s.setPriority(@priority)
    s.runCommand()
    @qseqGenerationJobName = s.getJobName()
    puts "Qseq Generation Job Name = " + @qseqGenerationJobName.to_s

    uploadAnalysisStartDate()
    puts "Creating flowcell definition XML"
    createFlowcellDefinitionXML()
    puts "Finished writing flowcell definition XML"

    # Added functionality to split qseq files
    splitQseqFiles()
  end

  # Helper method to upload analysis start date to LIMS for tracking purposes
  def uploadAnalysisStartDate()
    fcNameForLIMS = @pHelper.formatFlowcellNameForLIMS(@fcName)

    limsScript = "/stornext/snfs5/next-gen/Illumina/ipipe/third_party/" +
                 "setFlowCellAnalysisStartDate.pl"
    uploadCmd = "perl " + limsScript + " " + fcNameForLIMS
    output = `#{uploadCmd}`
   
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
#    splitCmd = "ruby " + File.dirname(__FILE__) + "/QseqSplitter.rb " + @fcName.to_s
    splitCmd = "ruby /stornext/snfs5/next-gen/Illumina/ipipe/lib/QseqSplitter.rb " +
               @fcName.to_s
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
end

flowcellName = ARGV[0]
obj = QseqGenerator.new(flowcellName)
