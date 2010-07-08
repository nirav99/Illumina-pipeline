#!/usr/bin/ruby
# This script generates the GERALD command that can be used to create GERALD
# directory in the in the flowcell to analyze
require 'fileutils'

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

    findFCPath()
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
  end

  private

  # This helper method searches for flowcell in list of volumes
  # If it does not find the path for flowcell, it aborts with an exception
    def findFCPath()
      @fcPath = ""
      @exptDir = ""
      
      # This represents directory hierarchy where GERALD directory
      # gets created. With HiSeqs, bustard directory could be called
      # BCLtoQSEQ instead of BaseCalls. 
      bustardDirPaths = Array.new
      bustardDirPaths << "Data/Intensities/BaseCalls"
      bustardDirPaths << "BCLtoQSEQ"

      # Flag to indicate if a valid Bustard directory was found
      foundBustardDir = false
      bustardDir      = ""
     
      # This represents location where to search for flowcell
      rootDir = "/stornext/snfs5/next-gen/Illumina/Instruments"

      # Populate an array with list of volumes where this flowcell
      # is expected to be found
      parentDir = Array.new
      parentDir << rootDir + "/EAS034"
      parentDir << rootDir + "/EAS376"
      parentDir << rootDir + "/700142"
      parentDir << rootDir + "/700166"

      parentDir.each{ |path|
        if File::exist?(path + "/" + @fcName) && 
           File::directory?(path + "/" + @fcName)
           @fcPath = path + "/" + @fcName
        end
      }

      if @fcPath.eql?("")
        puts "Error : Did not find path for flowcell : " + @fcName
        raise "Error in finding path for flowcell : " + @fcName
      end

      bustardDirPaths.each{ |bustPath|
        if File::exist?(@fcPath + "/" + bustPath) &&
           File::directory?(@fcPath + "/" + bustPath)
           foundBustardDir = true
           bustardDir      = bustPath
           puts "Found Bustard Directory : " + bustardDir.to_s
        end
      }

      if foundBustardDir == false
         puts "Error : Did not find Bustard results in " + @fcPath
         raise "Error in finding Bustard results in " + @fcPath
      else
        @exptDir = @fcPath + "/" + bustardDir
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

#obj = BuildGERALDCommand.new("100412_USI-EAS376_0007_PE1_FC61JT0AAXX")
#obj = BuildGERALDCommand.new("100120_USI-EAS376_0018_PE1_FC618U7AAXX")
