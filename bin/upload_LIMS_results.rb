#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'rubygems'
require 'hpricot'
require 'fileutils'
require 'PipelineHelper'
require 'FCBarcodeFinder'
require 'EmailHelper'

# Class to parse GERALD analysis summary for specified lane for specified
# read number (either read 1 or read 2).
class LaneResult

  # Class constructor
  def initialize(doc, laneNum)
    @xmlDoc = doc
    @laneNum = laneNum
  end

  # Generate a string with analysis results for LIMS upload
  def buildLIMSResultString(readNum)
    getPhasingPrePhasingResults(readNum)
    getLaneResultSummary(readNum)
    #getUniquenessResult()
    getAlignmentResult(readNum)

    currentTime = Time.new 
    puts "Current Time = " + currentTime.strftime("%Y-%m-%d")

    result = " LANE_YIELD_KBASES " + @totalBases.to_s + " PERCENT_ERROR_RATE_PF " +
             @errorPercent.to_s +  " CLUSTERS_RAW " + @rawClusters.to_s +
             " CLUSTERS_PF " + @pfClusters.to_s + " FIRST_CYCLE_INT_PF " +
             @avCycle1Int.to_s + " PERCENT_INTENSITY_AFTER_20_CYCLES_PF " +
             @perInt20Cycles.to_s + " PERCENT_PF_CLUSTERS " +
             @perPFClusters.to_s + " PERCENT_ALIGN_PF " + @perAlignPF.to_s +
             " ALIGNMENT_SCORE_PF " + @avgAlignScore.to_s + " PERCENT_PHASING " +
             @phasePercent.to_s + " PERCENT_PREPHASING " + @prePhasePercent.to_s +
             " RESULTS_PATH " + FileUtils.pwd
    # Uncomment the following two lines if we need to send this variable in the
    # upload string
             # + " ANALYSIS_END_DATE " +
             #  currentTime.strftime("%Y-%m-%d").to_s 
    if @foundUniquenessResult == true  #&& readNum == 1
      result = result + " UNIQUE_PERCENT " + @percentUnique.to_s
    end
    return result
  end

  private
  # Helper method to get uniqueness percentage result
  # TODO: Possible improvement - if many uniqueness files are present
  # select the right one based on lane number
  def getUniquenessResult()
    @foundUniquenessResult = false
    
    fileNames = Dir["Uniqueness_*.txt"]

    if fileNames.size < 1
      puts "Did not find Uniqueness file"
      return
    elsif fileNames.size > 1
      puts "Found multiple uniqueness files. Ignoring..."
      return
    end

    lines = IO.readlines(fileNames[0])
    lines.each do |line|
      if line.match(/\% Unique Reads/)
        @foundUniquenessResult = true
        line.gsub!(/^\D+/, "")
        @percentUnique = line.slice(/^[0-9\.]+/)
        return
      end
    end
  end

  def getAlignmentResult(readNum)
    @foundAlignmentResultFile = false

    fileName = Dir["BWA_Map_Stats.txt"]

    if fileName.size < 1
      puts "Did not find BWA alignment results file"
      return
    elsif fileName.size > 1
      puts "Found multiple alignment result files. Ignoring..."
      return
    else
      @foundAlignmentResultFile = true
    end

    # Alignment percentage array
    mapPercent   = Array.new
    errPercent   = Array.new

    IO.foreach(fileName[0]) do |line|
      if line.match(/\% Mapped Reads/)
        temp = line.gsub(/\% Mapped Reads\s+:\s+/, "")
        temp.strip!
        temp.gsub!(/\%$/, "")
        mapPercent << temp
      elsif line.match(/Mismatch Percentage/)
        temp = line.gsub(/Mismatch Percentage\s+:\s+/, "")
        temp.strip!
        temp.gsub!(/\%$/, "")
        errPercent << temp
      end
    end

    if readNum == 1
      @perAlignPF   = mapPercent[0]
      @errorPercent = errPercent[0]
    elsif readNum == 2 && mapPercent.size > 1
      @perAlignPF   = mapPercent[1]
      @errorPercent = errPercent[1]
    elsif readNum == 2 && mapPercent.size <= 1
      puts "Did not find mapping information for read 2" 
    end
  end

  # Method to read the LaneResultsSummary section of Summary.xml
  def getLaneResultSummary(readNum)
    (@xmlDoc/:'LaneResultsSummary Read').each do|read|
       readNumber = (read/'readNumber').inner_html

       if readNum.to_s.eql?(readNumber.to_s)
         (read/'Lane').each do|lane|
           laneNumber = (lane/'laneNumber').inner_html

           if laneNumber.to_s.eql?(@laneNum.to_s)
             tmp = (lane/'laneYield').inner_html 
             !isEmptyOrNull(tmp) ? @totalBases = tmp : @totalBases = 0
             tmp = (lane/'errorPF mean').inner_html
             !isEmptyOrNull(tmp) ? @errorPercent = tmp : @errorPercent = 0 
             tmp = (lane/'clusterCountRaw mean').inner_html
             !isEmptyOrNull(tmp) ? @rawClusters = tmp : @rawClusters = 0
             tmp = (lane/'clusterCountPF mean').inner_html
             !isEmptyOrNull(tmp) ? @pfClusters = tmp : @pfClusters = 0
             tmp = (lane/'averageAlignScorePF mean').inner_html
             !isEmptyOrNull(tmp) ? @avgAlignScore = tmp : @avgAlignScore = 0
             tmp = (lane/'percentClustersPF mean').inner_html
             !isEmptyOrNull(tmp) ? @perPFClusters = tmp : @perPFClusters = 0 
             tmp = (lane/'signal20AsPctOf1 mean').inner_html
             !isEmptyOrNull(tmp) ? @perInt20Cycles = tmp : @perInt20Cycles = 0 
             tmp = (lane/'percentUniquelyAlignedPF mean').inner_html
             !isEmptyOrNull(tmp) ? @perAlignPF = tmp : @perAlignPF = 0
             tmp = (lane/'oneSig mean').inner_html
             !isEmptyOrNull(tmp) ? @avCycle1Int = tmp : @avCycle1Int = 0 
           end
         end
       end
    end
  end

  # Method to get phasing and pre-phasing information for specified read type
  def getPhasingPrePhasingResults(readNum)
    (@xmlDoc/:'ExpandedLaneSummary Read').each do|read|
      readNumber = (read/'readNumber').inner_html

      if readNum.to_s.eql?(readNumber.to_s)
        (read/'Lane').each do|lane|
          laneNumber = (lane/'laneNumber').inner_html

          if laneNumber.to_s.eql?(@laneNum.to_s)
            tmp = (lane/'phasingApplied').inner_html
            !isEmptyOrNull(tmp) ? @phasePercent = tmp : @phasePercent = 0
            tmp = (lane/'prephasingApplied').inner_html
            !isEmptyOrNull(tmp) ? @prePhasePercent = tmp : @prePhasePercent = 0
          end
        end
      end
    end
  end

  # Private helper method to check if the string is null / empty
  def isEmptyOrNull(value)
    if value == nil || value.eql?("")
      return true
    else
      return false
    end
  end

  @laneNum         = ""  # Lane Number to Parse Results for
  @xmlDoc          = nil # Handle to Summary.xml
  @totalBases      = 0   # Total Purity Filtered Bases (in Kilobases)
  @errorPercent    = 0   # Percentage of Error Rate (Purity Filtered)
  @rawClusters     = 0   # Number of Raw Clusters
  @pfClusters      = 0   # Number of Purity Filtered Clusters
  @avCycle1Int     = 0   # Average 1st Cycle Intensity
  @perInt20Cycles  = 0   # Percentage Intensity after 20 cycles
  @perPFClusters   = 0   # Percentage of Purity Filtered clusters
  @perAlignPF      = 0   # Percentage of uniquely aligned reads
  @avgAlignScore   = 0   # Average Alignment Score
  @prePhasePercent = 0   # Pre-phasing Percentage
  @phasePercent    = 0   # Phasing Percentage
  @percentUnique   = 0   # Uniqueness Percentage
end

# Class to upload summary results for all lanes specified in config.txt
class UploadSummaryResults
  def initialize()
    @lanes  = ""
    @fcName = ""
    @limsScript = "/stornext/snfs5/next-gen/Illumina/ipipe/third_party/" +
                  "setIlluminaLaneStatus.pl"
    @pairedEnd = false                  
    @helper = PipelineHelper.new()
    @doc    = Hpricot::XML(open('Summary.xml'))
    @fcName = @helper.findFCName()
    @lanes  = @helper.findAnalysisLaneNumbers()
    obj     = FCBarcodeFinder.new
    @limsBarcode = obj.getBarcodeForLIMS()

    isFCPairedEnd()
  end

  # Method to upload results to LIMS
  # NOTE : THIS WORKS WITH ONLY ONE LANE IN GERALD DIRECTORY
  def uploadResults()
     puts "Generating LIMS upload string for lane : " + @lanes
     baseCmd = "perl " + @limsScript + " " + @limsBarcode +
               " ANALYSIS_FINISHED READ" 
     laneRes = LaneResult.new(@doc, @lanes)
     cmd = baseCmd + " 1 " + laneRes.buildLIMSResultString(1)
     puts cmd
     executeLIMSUploadCmd(cmd)

     if @pairedEnd == true
       cmd = baseCmd + " 2 " + laneRes.buildLIMSResultString(2) 
       puts cmd
       executeLIMSUploadCmd(cmd)
     end
  end

  private

  # Method to perform the upload operation. It aborts on detecting 
  # an upload error to LIMS
  def executeLIMSUploadCmd(cmd)
    output = `#{cmd}`
    exitStatus = $?
    output.downcase!
   
    # Present behavior of the LIMS perl script is to return the message
    # "Error: Cannot connect"
    # Note on Apr 19, 2010 : The script from LIMS returns zero for error
    # as well as success scenarios. Hence, dropping the check for exitStatus
    if output.match(/error/)  #|| exitStatus == 0
      puts "ERROR IN UPLOADING ANALYSIS RESULTS TO LIMS"
      puts "Error Message From LIMS : " + output

      # Currently the default behavior is to exit on detecting upload
      # error to LIMS. Could be suitably modified
      handleLIMSUploadError(cmd)
      exit -1
    else
      # If data was successfully uploaded, then a text "analysisFinishedState
      # has been successfully created" is reported.
      if output.match(/success/)
        puts "Successfully uploaded to LIMS"
      end
    end
  end

  # Find out if flowcell is fragment or paired
  # Sometimes, they abort READ2 on several flowcells. In these cases, the
  # Summary file will have information about both the reads, but it is incorrect
  # since the flowcell would have been analyzed in the fragment mode. Thus, we
  # also look for the number of sequence files in the directory. If there are
  # two sequence files and Summary shows two reads, it is treated as a paired
  # end flowcell, fragment otherwise.
  def isFCPairedEnd()
    (@doc/:'ExpandedLaneSummary Read').each do|read|
       readNumber = (read/'readNumber').inner_html
       if readNumber.to_s.eql?("2")
         @pairedEnd = true
       end
    end

    sequenceFiles = Dir["*_sequence.txt*"]
    
    if sequenceFiles.size < 2
      @pairedEnd = false
    end
  end

  # Method to send email if error was encountered while uploading
  # analysis results to LIMS
  def handleLIMSUploadError(cmd)
    obj          = EmailHelper.new()

    emailFrom    = "sol-pipe@bcm.edu"
    emailTo      = obj.getErrorRecepientEmailList()
    emailSubject = "Error in uploading analysis results to LIMS"
    emailText    = "Results could not be uploaded to LIMS. Cmd used was : " +
                   cmd
    obj.sendEmail(emailFrom, emailTo, emailSubject, emailText)
  end
end

 
obj = UploadSummaryResults.new()
obj.uploadResults()
exit 0
