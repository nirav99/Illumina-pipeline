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
  # Method to obtain chip design path from it's symbolic name. Soft links have
  # been created in p-illumina user's home directory that point soft links to
  # the actual path.
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

  # Method to run the capture stats calculation application
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

    if exitStatus == 0
      uploadResults()
    end
    exit exitStatus
  end

  # Method to upload capture stats results to LIMS, to be implemented when 
  # LIMS support is available.
  def uploadResults()
    puts "Uploading results to LIMS"
    summaryFile = Dir[@outputDir + "/*CoverageReport.csv"]

    if summaryFile == nil
      raise "Error : Did not find any capture stats summary file"
    end

    puts "Found Summary file : " + summaryFile[0].to_s
    resultObj = CaptureStatsResults.new(summaryFile[0]) 
    resultString = resultObj.toString()
    puts resultString
  end

  # Stub to email capture results.
  def emailResults()
  end
end

# Class to encapsulate capture stats results
class CaptureStatsResults
  def initialize(captureStatsSummaryFile)
    if captureStatsSummaryFile == nil || captureStatsSummaryFile.empty?()
      raise "Error : Name of capture stats summary file not specified"
    end
    if !File::exist?(captureStatsSummaryFile) ||
       !File::readable?(captureStatsSummaryFile)
       raise "Error : Specified Capture Stats Summary File : " + captureStatsSummaryFile 
             + " cannot be read"
    end
    initializeResultVariables()
    parseLine(captureStatsSummaryFile)
  end

  def parseLine(captureStatsSummaryFile)
    lines = IO.readlines(captureStatsSummaryFile)

    lines.each do |line|
      if line.index(":") != nil
        if line.match(/Aligned Reads On-Buffer/)
           tokens = line.split(",")
           @numBufferAlignedReads = tokens[1]
           @perBufferAlignedReads = formatPercentageValue(tokens[2])
        elsif line.match(/Aligned Reads On-Target/)
          tokens = line.split(",")
          @numTargetAlignedReads = tokens[1]
          @perTargetAlignedReads = formatPercentageValue(tokens[2])
        elsif line.match(/Targets Hit/)
          tokens = line.split(",")
          @numTargetsHit = tokens[1]
          @perTargetsHit = formatPercentageValue(tokens[2])
        elsif line.match(/Target Buffers Hit/)
          tokens = line.split(",")
          @numTargetBuffersHit = tokens[1]
          @perTargetBuffersHit = formatPercentageValue(tokens[2])  
        elsif line.match(/Total Targets/)
          tokens = line.split(",")
          @numTotalTargets = tokens[1] 
        elsif line.match(/Non target regions with high coverage/)
          tokens = line.split(",")
          @numTargetedBases = tokens[1]
        elsif line.match(/Bases Targeted/)
          tokens = line.split(",")
          @numTargetedBases = tokens[1]
        elsif line.match(/Buffer Bases/)
          tokens = line.split(",")
          @numBufferBases = tokens[1]
        elsif line.match(/Bases with 1\+ coverage/)
          tokens = line.split(",")
          @numBases1Coverage = tokens[1]
          @perBases1Coverage = formatPercentageValue(tokens[2])
        elsif line.match(/Bases with 4\+ coverage/)
          tokens = line.split(",")
          @numBases4Coverage = tokens[1]
          @perBases4Coverage = formatPercentageValue(tokens[2])
        elsif line.match(/Bases with 10\+ coverage/)
          tokens = line.split(",")
          @numBases10Coverage = tokens[1]
          @perBases10Coverage = formatPercentageValue(tokens[2])
        elsif line.match(/Bases with 20\+ coverage/)
          tokens = line.split(",")
          @numBases20Coverage = tokens[1]
          @perBases20Coverage = tokens[2]
        elsif line.match(/Bases with 40\+ coverage/)
          tokens = line.split(",")
          @numBases40Coverage = tokens[1]
          @perBases40Coverage = tokens[2]
          break
        end
      end
    end
    show()
  end

  def show()
    puts "Buffer aligned reads = " + @numBufferAlignedReads.to_s + " " + @perBufferAlignedReads.to_s
    puts "Target aligned reads = " + @numTargetAlignedReads.to_s + " " + @perTargetAlignedReads.to_s
    puts "Targets hit = " + @numTargetsHit.to_s + " " + @perTargetsHit.to_s
    puts "Target buffers hit = " + @numTargetBuffersHit.to_s + " " + @perTargetBuffersHit.to_s
    puts "Total targets = " + @numTotalTargets.to_s
    puts "Non target hits = " + @numNonTarget.to_s
    puts "Bases on target = " + @numTargetedBases.to_s
    puts "Buffer bases = " + @numBufferBases.to_s 
    puts "Bases with 1+ coverage = " + @numBases1Coverage.to_s + " " + @perBases1Coverage.to_s
    puts "Bases with 4+ coverage = " + @numBases4Coverage.to_s + " " + @perBases4Coverage.to_s
    puts "Bases with 10+ coverage = " + @numBases10Coverage.to_s + " " + @perBases10Coverage.to_s
    puts "Bases with 20+ coverage = " + @numBases20Coverage.to_s + " " + @perBases20Coverage.to_s
    puts "Bases with 40+ coverage = " + @numBases40Coverage.to_s + " " + @perBases40Coverage.to_s
  end

  # Method to create a result string to upload to LIMS
  def toString()
    result = "BUFFER_ALIGNED_READS " + @numBufferAlignedReads.to_s +
    " PERCENT_BUFFER_ALIGNED_READS " + @perBufferAlignedReads.to_s +
    " TARGET_ALIGNED_READS " + @numTargetAlignedReads.to_s +
    " PERCENT_TARGET_ALIGNED_READS " + @perTargetAlignedReads.to_s +
    " TARGETS_HIT " + @numTargetsHit.to_s + "PERCENT_TARGETS_HIT " + @perTargetsHit.to_s +
    " TARGET_BUFFERS_HIT " + @numTargetBuffersHit.to_s +
    " PER_TARGET_BUFFERS_HITS " + @perTargetBuffersHit.to_s +
    " TOTAL_TARGETS " + @numTotalTargets.to_s +
    " HIGH_COVERAGE_NON_TARGET_HITS " + @numNonTarget.to_s +
    " BASES_ON_TARGET " + @numTargetedBases.to_s + "BASES_ON_BUFFER " + @numBufferBases.to_s +
    " 1_COVERAGE_BASES " + @numBases1Coverage.to_s + 
    " PER_1_COVERAGE_BASES " + @perBases1Coverage.to_s +
    " 4_COVERAGE_BASES " + @numBases4Coverage.to_s + 
    " PER_4_COVERAGE_BASES " + @perBases4Coverage.to_s +
    " 10_COVERAGE_BASES " + @numBases10Coverage.to_s + 
    " PER_10_COVERAGE_BASES " + @perBases10Coverage.to_s +
    " 20_COVERAGE_BASES " + @numBases20Coverage.to_s + 
    " PER_20_COVERAGE_BASES " + @perBases20Coverage.to_s +
    " 40_COVERAGE_BASES " + @numBases40Coverage.to_s + 
    " PER_40_COVERAGE_BASES " + @perBases40Coverage.to_s
    return result
  end

  private
  # Initialize all variables to default value
  def initializeResultVariables()
    @numBufferAlignedReads = 0 # Num. reads aligned on buffer
    @perBufferAlignedReads = 0 # Percentage of reads aligned on buffer
    @numTargetAlignedReads = 0 # Num. reads aligned on target
    @perTargetAlignedReads = 0 # Percentage of reads aligned on target
    @numTargetsHit         = 0 # Number of targets hit
    @perTargetsHit         = 0 # Percentage of targets hit
    @numTargetBuffersHit   = 0 # Num. target buffers hit
    @perTargetBuffersHit   = 0 # Percentage of target buffers hit
    @numTotalTargets       = 0 # Number of total targets
    @numNonTarget          = 0 # Number of non-target hits with high coverage
    @numTargetedBases      = 0 # Number of bases targeted
    @numBufferBases        = 0 # Number of buffer bases
    @numBases1Coverage     = 0 # Num. bases with 1+ coverage
    @perBases1Coverage     = 0 # Percentage of bases with 1+ coverage
    @numBases4Coverage     = 0 # Percentage of bases with 4+ coverage
    @perBases4Coverage     = 0 # Percentage of bases with 4+ coverage
    @numBases10Coverage    = 0 # Num. bases with 10+ coverage
    @perBases10Coverage    = 0 # Percentage of bases with 10+ coverage
    @numBases20Coverage    = 0 # Num. bases with 20+ coverage
    @perBases20Coverage    = 0 # Percentage of bases with 20+ coverage
    @numBases40Coverage    = 0 # Percentage of bases with 40+ coverage
    @perBases40Coverage    = 0 # Percentage of bases with 40+ coverage
  end

  # Percentage values are reported with the format (xx.xx%) in the capture
  # stats summary file. Use the following function to extract the actual
  # numeric value
  def formatPercentageValue(input)
    output = input.gsub(/\(/, "")
    output.gsub!(/%\)$/, "")
    return output
  end 
end

bamFile    = ARGV[0]
chipDesign = ARGV[1]
obj = CaptureStats.new(bamFile, chipDesign)
