#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

#Author: Nirav Shah niravs@bcm.edu

require 'Scheduler'
require 'PipelineHelper'
require 'BWAParams'
require 'fileutils'

class CaptureStats
  def initialize(inputFile, chipDesign)
    @captureCodeDir = "/stornext/snfs5/next-gen/software/hgsc/capture_stats"
    @outputDir      = "capture_stats"
    @resultPrefix   = "cap_stats"

    begin
      if inputFile == nil || inputFile.empty?()
        raise "BAM File name must be specified"
      elsif !File::exist?(inputFile) || !File::readable?(inputFile)
        raise "Specified file : " + inputFile.to_s + " can not be read"
      elsif chipDesign == nil || chipDesign.empty?()
        raise "Chip Design Name must be specified"
      end
      chipDesignPath = getChipDesignPath(chipDesign) 
      runCommand(inputFile, chipDesignPath)
    rescue Exception => e
      puts e.message
      exit -1
    end
  end

  private
  def getChipDesignPath(cDesign)
    cdPath = nil
    homeDir = File.expand_path("~")

    filesInHome = Dir[homeDir + "/*"]

    filesInHome.each do |file|
      designName = File.basename(file)
      if designName.casecmp(cDesign) == 0
        cdPath = file
        break;
      end
    end

    if cdPath == nil
      raise "Did not find chip design path for : " + chipDesign
    end
    puts "Found chip design path : " + cdPath
    return cdPath
  end

  def runCommand(bamFile, chipDesignPath)
    FileUtils.mkdir(@outputDir)
    cmd = "java -Xmx8G -cp " + @captureCodeDir + "/picard-1.07.jar:" + @captureCodeDir +
           "/sam-1.07.jar:" + @captureCodeDir + " CaptureStatsBAM5"
    cmd = cmd + " -o " + @outputDir + "/" + @resultPrefix.to_s + " -t " +
          chipDesignPath.to_s + " -i " + bamFile + " -d -w"

    puts "Running the following command for capture stats : "
    puts cmd
    `#{cmd}`
    exitStatus = $?
    puts "Exit status of Capture Stats Command : " + exitStatus.to_s
    exit exitStatus
  end

  # Method to upload capture stats results to LIMS, to be implemented when 
  # LIMS support is available.
  def uploadResults()
    puts "Uploading results to LIMS"
  end

  # Stub to email capture results.
  def emailResults()
  end
end

bamFile    = ARGV[0]
chipDesign = ARGV[1]
obj = CaptureStats.new(bamFile, chipDesign)
