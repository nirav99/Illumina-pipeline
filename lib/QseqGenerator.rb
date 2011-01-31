#!/usr/bin/ruby

require 'fileutils'
require 'PipelineHelper'
require 'Scheduler'

# Class to generate qseq files in the base calls directory
class QseqGenerator

  # Class constructor - to prepare base calls directory to generate qseq
  def initialize(flowcellName)
    @scriptName = "/stornext/snfs5/next-gen/Illumina/GAPipeline/" +
                  "BclConverter-1.7.1/bin/setupBclToQseq.py"
    @fcName = flowcellName

    if @fcName == nil || @fcName.eql?("")
      raise "Flowcell name is null or empty"
    end

    pHelper = PipelineHelper.new
    @baseCallsDir = pHelper.findBaseCallsDir(@fcName)
    @intensityDir = @baseCallsDir.gsub(/\/[a-zA-Z0-9_]+$/, "")

    cmd = @scriptName + " -i " + @baseCallsDir + " -p " + @intensityDir +
           " -o " + @baseCallsDir + " --in-place --overwrite"
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

=begin
  # Methods to return job ID and job name on the cluster
  def getJobName()
    return @jobName
  end 

  def getJobID()
    return @jobID
  end
=end

  private
  # Method to run "make" command on the cluster
  # This generates qseq files.
  def runMake()
    puts "Running make command to generate qseq files"
    s = Scheduler.new(@fcName + "_Generate_Qseq", "make -j8")
    s.setMemory(28000)
    s.setNodeCores(6)
    s.setPriority("high")
    s.runCommand()
    @qseqGenerationJobName = s.getJobName()
    puts "Qseq Generation Job Name = " + @qseqGenerationJobName.to_s

    # PLEASE NOTE: The function below helps to create MOAB dependency between
    # GERALD jobs and qseq generator jobs. To disable this functionality, please
    # comment out the line below.
    writeJobNameToBaseCallsDir()

    # Added functionality to split qseq files
    splitQseqFiles()
  end

  # Helper method to write job name to base calls dir
  # Intention is that subsequent jobs can read this ID and put
  # a dependency in their scheduling
  def writeJobNameToBaseCallsDir()
    fileName = @baseCallsDir + "/bclToQseqJobName"
    file = File.new(fileName, "w")
    
    if file
       file.syswrite(@qseqGenerationJobName.to_s)
       file.close
    else
       puts "Unable to open file : " + fileName
    end
  end

  # For a multiplexed flowcell, the qseq files have to be split based on the
  # barcode information. This method achieves that through the supporting
  # script.
  # If this flowcell is not multiplexed, the supporting script will simply
  # return without attempting to split any qseq files.
  def splitQseqFiles()
    splitCmd = "ruby " + File.dirname(__FILE__) + "/QseqSplitter.rb " + @fcName.to_s
    puts "Command to split qseq files : " + splitCmd

    s = Scheduler.new(@fcName + "_Split_Qseq", splitCmd)
    s.setMemory(2000)
    s.setNodeCores(1)
    s.setPriority("high")
    s.setDependency(@qseqGenerationJobName.to_s)
    s.runCommand()
    @splitQseqJobName = s.getJobName()
    puts "Splitting Qseq Job Name  = " + @splitQseqJobName.to_s
  end
end

flowcellName = ARGV[0]
obj = QseqGenerator.new(flowcellName)
