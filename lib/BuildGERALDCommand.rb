#!/usr/bin/ruby
# This script generates the GERALD command that can be used to create GERALD
# directory in the in the flowcell to analyze
require 'fileutils'
require 'PipelineHelper'

class BuildGERALDCommand
  def initialize(fcName)
#    @pipelinePath = "/stornext/snfs5/next-gen/Illumina/GAPipeline/current" +
#                    "/bin/GERALD.pl"

    @pipelinePath = "/stornext/snfs5/next-gen/Illumina/GAPipeline/CASAVA1_7/" +
                    "CASAVA-1.7.0-Install/bin/GERALD.pl"

    currentDir = FileUtils.pwd

    @configPath = currentDir + "/config.txt"
    @outputFile = currentDir + "/generate_makefiles.sh"
    @fcName     = fcName

    if @fcName == nil || @fcName.eql?("")
      raise "Flowcell name is null or empty"
    end

    if !File::exist?(@configPath)
      raise "Config.txt not present in : " + currentDir
    end

    # Locate base calls directory for the specified flowcell
    @pipelineHelperInstance = PipelineHelper.new
    @exptDir = @pipelineHelperInstance.findBaseCallsDir(@fcName)

    fileHandle = File.new(@outputFile, "w")

    if !fileHandle || fileHandle == nil
      raise "Could not create file : generate_makefiles.sh"
    end

    # Write the command to generate GERALD directory
    fileHandle.write(@pipelinePath + " \\\n")
    fileHandle.write(@configPath + " \\\n")
    fileHandle.write("--EXPT_DIR \\\n")
    fileHandle.write(@exptDir + " \\\n")
    fileHandle.write("--make \\\n")
    fileHandle.write("&> " + @outputFile  + ".log\n")
    fileHandle.close()
    FileUtils.chmod(0755, @outputFile)

    filterPhixReads()
  end

  private

  def filterPhixReads()
    if @pipelineHelperInstance.isFCHiSeq(@fcName) == true
      # Add a file "filterphix" in EXPT_DIR
      # Script filtering out phix reads should check for this file before
      # proceeding

      currDir = FileUtils.pwd()
      FileUtils.cd(@exptDir)
      `touch filterphix`
      FileUtils.cd(currDir)
    end
  end

    @pipelinePath = "" # Path to GERALD installation 
    @configPath   = "" # Path to GERALD config file
    @logFilePath  = "" # Path to log file created after executing GERALD command
    @fcName       = "" # Full name of Flowcell
    @fcPath       = "" # Path of Flowcell, including its full name
    @exptDir      = "" # Experiment directory in the flowcell (usually Bustard results)
    @outputFile   = "" # File containing GERALD command
end

#obj = BuildGERALDCommand.new("100719_USI-EAS376_0003_PE1_FC6263EAAXX")
#obj = BuildGERALDCommand.new("100120_USI-EAS376_0018_PE1_FC618U7AAXX")
