#!/usr/bin/ruby

require 'fileutils'
require 'PipelineHelper'
require 'Scheduler'

# Class to generate qseq files from the base calls directory
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

  # Methods to return LSF job ID and LSF job name
  def getJobName()
    return @jobName
  end 

  def getJobID()
    return @jobID
  end

  private
  # Method to run "make" command with LSF
  def runMake()
    s = Scheduler.new(@fcName + "_Generate_Qseq", "make -j8")
    s.setMemory(28000)
    s.setNodeCores(8)
    s.setPriority("high")
    s.runCommand()
    @jobID = s.getJobID()
    puts "FOUND JOB ID = " + @jobID.to_s
    @jobName = s.getJobName()
    puts "FOUND JOB NAME = " + @jobName

    # PLEASE NOTE: The function below helps to create MOAB dependency between
    # GERALD jobs and qseq generator jobs. To disable this functionality, please
    # comment out the line below.
    writeJobNameToBaseCallsDir()
  end

  # Helper method to write job name to base calls dir
  # Intention is that subsequent jobs can read this ID and put
  # a dependency in their scheduling
  def writeJobNameToBaseCallsDir()
    fileName = @baseCallsDir + "/bclToQseqJobName"
    file = File.new(fileName, "w")
    
    if file
       file.syswrite(@jobName)
       file.close
    else
       puts "Unable to open file : " + fileName
    end
  end
end

flowcellName = ARGV[0]
obj = QseqGenerator.new(flowcellName)
