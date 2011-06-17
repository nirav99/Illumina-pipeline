#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

#Author: Nirav Shah niravs@bcm.edu

require 'Scheduler'
require 'BWAParams'
require 'fileutils'
require 'FCBarcodeFinder'
require 'EmailHelper'

# Class to encapsulate capture metrics calculation
class CaptureStats
  def initialize(inputFile, chipDesignPath)
    @captureCodeDir = "/stornext/snfs5/next-gen/software/hgsc/capture_stats"
    @outputDir      = "capture_stats"
    @resultPrefix   = "cap_stats"
    @captureResult  = nil # Instance of CaptureStatsResult class
    @limsScript     = "/stornext/snfs5/next-gen/Illumina/ipipe/third_party/" +
                      "setIlluminaCaptureResults.pl"

    if !chipDesignPath.match(/p-illumina/)
      chipDesignPath = "/users/p-illumina/" + chipDesignPath.to_s
    end
    begin
      if inputFile == nil || inputFile.empty?()
        raise "BAM File name must be specified"
      elsif !File::exist?(inputFile) || !File::readable?(inputFile)
        raise "Specified file : " + inputFile.to_s + " can not be read"
      elsif chipDesignPath == nil || chipDesignPath.empty?()
        raise "Chip Design Name must be specified"
      elsif !File::exist?(chipDesignPath)
        raise "Chip Design Path : " + chipDesignPath + " does not exist"
      end
      puts "Chip Design Path : " + chipDesignPath.to_s

      # Obtain flowcell barcode for uploading results to LIMS and sending email
      barcodeObj = FCBarcodeFinder.new()
      @fcBarcode = barcodeObj.getBarcodeForLIMS()

      runCommand(inputFile, chipDesignPath)
    rescue Exception => e
      puts e.message
      puts e.backtrace.inspect
#      exit -1
      exit 0
    end
    exit 0
  end

  private
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

    parseResults()
    emailResults()
    uploadToLIMS()
    puts "Completed Everything"
  end

  # Method to parse capture stats summary file and instantiate
  # CaptureStatsResults object
  # Handle the case where capture stats summary file is missing
  def parseResults()
    puts "Uploading results to LIMS"
    summaryFile = Dir[@outputDir + "/*CoverageReport.csv"]

    if summaryFile == nil
      @captureResults = CaptureStatsResults.new(nil)
    else
      puts "Found Summary file : " + summaryFile[0].to_s
      @captureResults = CaptureStatsResults.new(summaryFile[0]) 
    end
  end

  # Method to email capture results.
  def emailResults()
    obj          = EmailHelper.new()
    emailSubject = "Illumina Capture Stats : Flowcell " + @fcBarcode.to_s
    emailFrom    = "sol-pipe@bcm.edu" 
    emailText    = @captureResults.formatForSTDOUT()
    emailTo      = obj.getCaptureResultRecepientEmailList()

    obj.sendEmail(emailFrom, emailTo, emailSubject, emailText)
  end

  # Method to upload capture stats to LIMS
  def uploadToLIMS()
    result = @captureResults.formatForLIMSUpload()
    cmd = "perl " + @limsScript + " " + @fcBarcode.to_s + " CAPTURE_FINISHED " + result.to_s
    puts "Executing command : " + cmd
    output = `#{cmd}`
    exitStatus = $?
    output.downcase!
    puts "Output from LIMS : " + output
    #TODO: Check if an error occurred while uploading and handle it

    if output.match(/capturesummary has successfully/)
      puts "LIMS acknowledged receiving the data. Current Time : " + Time.now.to_s
    end
  end
end


# Class to encapsulate capture stats results
class CaptureStatsResults

  # Capture stats 
  def initialize(captureStatsSummaryFile)
    initializeResultVariables()

    if captureStatsSummaryFile != nil && !captureStatsSummaryFile.empty?()
       if !File::exist?(captureStatsSummaryFile) || !File::readable?(captureStatsSummaryFile)
         raise "Error : Specified Capture Stats Summary File : " + captureStatsSummaryFile 
             + " cannot be read"
       end
       parseLine(captureStatsSummaryFile)
    end
  end

  def parseLine(captureStatsSummaryFile)
    lines = IO.readlines(captureStatsSummaryFile)

    lines.each do |line|
      if line.index(":") != nil
        if line.match(/Total Reads Produced/)
           tokens = line.split(",")
           @totalReadsProduced = tokens[1].strip
        elsif line.match(/Duplicate Reads/)
           tokens = line.split(",")
           @numDuplicateReads = tokens[1].strip
           @perDuplicateReads = formatPercentageValue(tokens[2].strip)
        elsif line.match(/Total Reads Aligned/)
           tokens = line.split(",")
           @numAlignedReads      = tokens[1].strip
           @perAlignedReads      = formatPercentageValue(tokens[2].strip)
           @numReadsPaired       = tokens[4].strip
           @numReadAndMatePaired = tokens[6].strip
        elsif line.match(/Aligned Reads On-Buffer/)
           tokens = line.split(",")
           @numBufferAlignedReads = tokens[1].strip
           @perBufferAlignedReads = formatPercentageValue(tokens[2].strip)
        elsif line.match(/Aligned Reads On-Target/)
          tokens = line.split(",")
          @numTargetAlignedReads = tokens[1].strip
          @perTargetAlignedReads = formatPercentageValue(tokens[2].strip)
        elsif line.match(/Average Coverage/)
          tokens = line.split(",")
          @avgCoverage = removeParentheses(tokens[2].strip)
        elsif line.match(/Reads that hit target or buffer/)
          tokens = line.split(",")
          @numReadsTargetBuffer = tokens[1].strip
          @perReadsTargetBuffer = formatPercentageValue(tokens[2].strip)
        elsif line.match(/Total Aligned Reads/) && line.match(/expected/)
          tokens = line.split(",")
          @totalExpAlignedReads = tokens[1].strip
        elsif line.match(/Total Aligned Reads/) && line.match(/calculated/)
          tokens = line.split(",")
          @totalCalcAlignedReads = tokens[1].strip
        elsif line.match(/Targets Hit/)
          tokens = line.split(",")
          @numTargetsHit = tokens[1].strip
          @perTargetsHit = formatPercentageValue(tokens[2].strip)
        elsif line.match(/Target Buffers Hit/)
          tokens = line.split(",")
          @numTargetBuffersHit = tokens[1].strip
          @perTargetBuffersHit = formatPercentageValue(tokens[2].strip)  
        elsif line.match(/Total Targets/)
          tokens = line.split(",")
          @numTotalTargets = tokens[1].strip 
        elsif line.match(/Non target regions with high coverage/)
          tokens = line.split(",")
          @numTargetedBases = tokens[1].strip
        elsif line.match(/Bases Targeted/)
          tokens = line.split(",")
          @numTargetedBases = tokens[1].strip
        elsif line.match(/Buffer Bases/)
          tokens = line.split(",")
          @numBufferBases = tokens[1].strip
        elsif line.match(/Bases with 1\+ coverage/)
          tokens = line.split(",")
          @numBases1Coverage = tokens[1].strip
          @perBases1Coverage = formatPercentageValue(tokens[2].strip)
        elsif line.match(/Bases with 4\+ coverage/)
          tokens = line.split(",")
          @numBases4Coverage = tokens[1].strip
          @perBases4Coverage = formatPercentageValue(tokens[2].strip)
        elsif line.match(/Bases with 10\+ coverage/)
          tokens = line.split(",")
          @numBases10Coverage = tokens[1].strip
          @perBases10Coverage = formatPercentageValue(tokens[2].strip)
        elsif line.match(/Bases with 20\+ coverage/)
          tokens = line.split(",")
          @numBases20Coverage = tokens[1].strip
          @perBases20Coverage = formatPercentageValue(tokens[2].strip)
        elsif line.match(/Bases with 40\+ coverage/)
          tokens = line.split(",")
          @numBases40Coverage = tokens[1].strip
          @perBases40Coverage = formatPercentageValue(tokens[2].strip)
          break
        end
      end
    end
    puts formatForSTDOUT() 
  end

  # Return the string in a format suitable for display on screen / email
  def formatForSTDOUT()
    output = "Total Reads Produced = " + @totalReadsProduced.to_s + "\r\n" +
     "Duplicate Reads = " + @numDuplicateReads.to_s + " (" + @perDuplicateReads.to_s + ")%\r\n" +
     "Total Reads Aligned = " + @numAlignedReads.to_s + " (" + @perAlignedReads.to_s + ")%\r\n" +
     "Paired Reads = " + @numReadsPaired.to_s + "\r\n" +
     "Reads Paired with Mapped Mates = " + @numReadAndMatePaired.to_s + "\r\n" +
     "Buffer Aligned Reads = " + @numBufferAlignedReads.to_s + " (" + @perBufferAlignedReads.to_s + ")%\r\n" + 
     "Target Aligned Reads = " + @numTargetAlignedReads.to_s + " (" + @perTargetAlignedReads.to_s + ")%\r\n" +
     "Average Coverage = " + @avgCoverage.to_s + "\r\n" +
     "Reads on Target or Buffer = " + @numReadsTargetBuffer.to_s + " (" + @perReadsTargetBuffer.to_s +  ")%\r\n" +
     "Total Aligned Reads (Expected) = " + @totalExpAlignedReads.to_s + "\r\n" +
     "Total Aligned Reads (Calculated) = " + @totalCalcAlignedReads.to_s + "\r\n" +
     "Targets Hit = " + @numTargetsHit.to_s + " (" + @perTargetsHit.to_s + ")%\r\n" +
     "Target Buffers Hit = " + @numTargetBuffersHit.to_s + " (" + @perTargetBuffersHit.to_s + ")%\r\n" +
     "Total Targets = " + @numTotalTargets.to_s + "\r\n" +
     "Non Target Hits = " + @numNonTarget.to_s + "\r\n" +
     "Bases on Target = " + @numTargetedBases.to_s + "\r\n" +
     "Buffer Bases = " + @numBufferBases.to_s + "\r\n" + 
     "Bases with 1+ Coverage = " + @numBases1Coverage.to_s + " (" + @perBases1Coverage.to_s + ")%\r\n" +
     "Bases with 4+ Coverage = " + @numBases4Coverage.to_s + " (" + @perBases4Coverage.to_s + ")%\r\n" +
     "Bases with 10+ Coverage = " + @numBases10Coverage.to_s + " (" + @perBases10Coverage.to_s + ")%\r\n" +
     "Bases with 20+ Coverage = " + @numBases20Coverage.to_s + " (" + @perBases20Coverage.to_s + ")%\r\n" +
     "Bases with 40+ Coverage = " + @numBases40Coverage.to_s + " (" + @perBases40Coverage.to_s + ")%\r\n"
     return output
  end

=begin
  # Method to create a result string to upload to LIMS
  def formatForLIMSUpload_old()
    result = "BUFFER_ALIGNED_READS " + @numBufferAlignedReads.to_s +
    " PERCENT_BUFFER_ALIGNED_READS " + @perBufferAlignedReads.to_s +
    " TARGET_ALIGNED_READS " + @numTargetAlignedReads.to_s +
    " PERCENT_TARGET_ALIGNED_READS " + @perTargetAlignedReads.to_s +
    " TARGETS_HIT " + @numTargetsHit.to_s + " PERCENT_TARGETS_HIT " + @perTargetsHit.to_s +
    " TARGET_BUFFERS_HIT " + @numTargetBuffersHit.to_s +
    " PER_TARGET_BUFFERS_HITS " + @perTargetBuffersHit.to_s +
    " TOTAL_TARGETS " + @numTotalTargets.to_s +
    " HIGH_COVERAGE_NON_TARGET_HITS " + @numNonTarget.to_s +
    " BASES_ON_TARGET " + @numTargetedBases.to_s + " BASES_ON_BUFFER " + @numBufferBases.to_s +
    " ONE_COVERAGE_BASES " + @numBases1Coverage.to_s + 
    " PER_ONE_COVERAGE_BASES " + @perBases1Coverage.to_s +
    " FOUR_COVERAGE_BASES " + @numBases4Coverage.to_s + 
    " PER_FOUR_COVERAGE_BASES " + @perBases4Coverage.to_s +
    " TEN_COVERAGE_BASES " + @numBases10Coverage.to_s + 
    " PER_TEN_COVERAGE_BASES " + @perBases10Coverage.to_s +
    " TWENTY_COVERAGE_BASES " + @numBases20Coverage.to_s + 
    " PER_TWENTY_COVERAGE_BASES " + @perBases20Coverage.to_s +
    " FORTY_COVERAGE_BASES " + @numBases40Coverage.to_s + 
    " PER_FORTY_COVERAGE_BASES " + @perBases40Coverage.to_s
    return result
  end
=end

  # Method to create a result string to upload to LIMS
  def formatForLIMSUpload()
    result = "TOTAL_READS " + @totalReadsProduced.to_s +
    " DUPLICATE_READS " + @numDuplicateReads.to_s +
    " PERCENT_DUPLICATE_READS " + @perDuplicateReads.to_s +
    " TOTAL_ALIGNED_READS " + @numAlignedReads.to_s +
    " PERCENT_ALIGNED_READS " + @perAlignedReads.to_s +
    " READS_PAIRED " + @numReadsPaired.to_s + 
    " READS_PAIRED_MAPPED_MATES " + @numReadAndMatePaired.to_s +
    " BUFFER_ALIGNED_READS " + @numBufferAlignedReads.to_s +
    " PERCENT_BUFFER_ALIGNED_READS " + @perBufferAlignedReads.to_s +
    " TARGET_ALIGNED_READS " + @numTargetAlignedReads.to_s +
    " PERCENT_TARGET_ALIGNED_READS " + @perTargetAlignedReads.to_s +
    " AVERAGE_COVERAGE " + @avgCoverage.to_s +
    " READS_ON_TARGET_OR_BUFFER " + @numReadsTargetBuffer.to_s +
    " PERCENT_READS_ON_TARGET_OR_BUFFER " + @perReadsTargetBuffer.to_s +
    " TOTAL_EXPECTED_ALIGNED_READS " + @totalExpAlignedReads.to_s +
    " TOTAL_CALC_ALIGNED_READS " + @totalCalcAlignedReads.to_s + 
    " TARGETS_HIT " + @numTargetsHit.to_s + " PERCENT_TARGETS_HIT " + @perTargetsHit.to_s +
    " TARGET_BUFFERS_HIT " + @numTargetBuffersHit.to_s +
    " PER_TARGET_BUFFERS_HITS " + @perTargetBuffersHit.to_s +
    " TOTAL_TARGETS " + @numTotalTargets.to_s +
    " HIGH_COVERAGE_NON_TARGET_HITS " + @numNonTarget.to_s +
    " BASES_ON_TARGET " + @numTargetedBases.to_s + " BASES_ON_BUFFER " + @numBufferBases.to_s +
    " ONE_COVERAGE_BASES " + @numBases1Coverage.to_s +
    " PER_ONE_COVERAGE_BASES " + @perBases1Coverage.to_s +
    " FOUR_COVERAGE_BASES " + @numBases4Coverage.to_s +
    " PER_FOUR_COVERAGE_BASES " + @perBases4Coverage.to_s +
    " TEN_COVERAGE_BASES " + @numBases10Coverage.to_s +
    " PER_TEN_COVERAGE_BASES " + @perBases10Coverage.to_s +
    " TWENTY_COVERAGE_BASES " + @numBases20Coverage.to_s +
    " PER_TWENTY_COVERAGE_BASES " + @perBases20Coverage.to_s +
    " FORTY_COVERAGE_BASES " + @numBases40Coverage.to_s +
    " PER_FORTY_COVERAGE_BASES " + @perBases40Coverage.to_s
    return result
  end

  private
  # Initialize all variables to default value
  def initializeResultVariables()
    @totalReadsProduced    = 0 # Total reads
    @numDuplicateReads     = 0 # Num. duplicate reads
    @perDuplicateReads     = 0 # Percentage of duplicate reads
    @numAlignedReads       = 0 # Num. of reads aligned
    @perAlignedReads       = 0 # Percentage of reads aligned
    @numReadsPaired        = 0 # Total pairs of reads
    @numReadAndMatePaired  = 0 # Read pairs with mapped mates
    @numBufferAlignedReads = 0 # Num. reads aligned on buffer
    @perBufferAlignedReads = 0 # Percentage of reads aligned on buffer
    @numTargetAlignedReads = 0 # Num. reads aligned on target
    @perTargetAlignedReads = 0 # Percentage of reads aligned on target
    @avgCoverage           = 0 # Average coverage
    @numReadsTargetBuffer  = 0 # Num. reads hitting target or buffer
    @perReadsTargetBuffer  = 0 # Percentage of reads hitting target or buffer
    @totalExpAlignedReads  = 0 # Total expected number of aligned reads
    @totalCalcAlignedReads = 0 # Total calculated number of aligned reads 
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

  # Method to remove parentheses around 
  def removeParentheses(input)
    output = input.gsub(/\(/, "")
    output.gsub!(/\)/, "")
    return output
  end
end

bamFile    = ARGV[0]
chipDesign = ARGV[1]
obj = CaptureStats.new(bamFile, chipDesign)
