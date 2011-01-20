#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'rubygems'
require 'hpricot'
require 'fileutils'
require 'net/smtp'
require 'PipelineHelper'
require 'FCBarcodeFinder'
require 'EmailHelper'

#This class is a wrapper for SlxUniqueness.jar to find unique reads.
#It works on per-lane basis only.
class FindUniqueReads
  def initialize()
    jarName = "/stornext/snfs5/next-gen/Illumina/ipipe/java/SlxUniqueness.jar"
    #jarName = "/stornext/snfs5/next-gen/Illumina/ipipe/java/SlxUniqueness/SlxUniqueness.jar"
    @lanes   = ""  # Lanes to consider for running uniqueness
    @fcName  = ""
    @limsBarcode = ""
    javaVM   = "-Xmx8G" # Specifies maximum memory size of JVM
    @coreCmd = "java " + javaVM + " -jar " + jarName
    @helper  = PipelineHelper.new

    begin
      #findLaneNumbers()
      #findFCName()
      @lanes  = @helper.findAnalysisLaneNumbers()
      @fcName = @helper.findFCName()

      obj          = FCBarcodeFinder.new
      @limsBarcode = obj.getBarcodeForLIMS()
      findUniqueness()
    rescue Exception => e
      puts e.message
      puts e.backtrace.inspect
      exit -1
    end
  end

  private

  # Method to build JAR command for the specified lane.
  # Works with only one lane per GERALD directory
  def findUniqueness()
    puts "Generating Uniqueness for lane : " + @lanes.to_s
    fileNames = findSequenceFileNames(@lanes.to_s)
    buildJarCommand(fileNames)
  end

  def buildJarCommand(fileNames)
    resultFileName = "Uniqueness_" + @limsBarcode.to_s + ".txt"

    # Create temp directory
    tmpDir = "tmp_" + @lanes.to_s
    FileUtils.mkdir(tmpDir)

    # Select analysis as fragment or paired
    if fileNames.length == 2
      analysisMode = "paired"
    else
      analysisMode = "fragment"
    end
    cmd = @coreCmd + " AnalysisMode=" + analysisMode + " TmpDir=" + tmpDir +
          " DetectAdaptor=true "
   
    fileNames.each do |fname|
      cmd = cmd + " Input=" + fname
    end
    puts cmd

    resultFile = File.new(resultFileName, "w")
    resultFile.write("Flowcell Lane : " + @limsBarcode.to_s)
    resultFile.close()
#    resultFile.write("")
    puts "Computing Uniqueness Results"
    cmd = cmd + " >> " + resultFileName
    `#{cmd}`

    emailUniquenessResults(resultFileName)
    puts "Finished Computing Uniqueness Results."

    # Upload uniqueness results to LIMS
    uploadResultsToLIMS(resultFileName)

    # Remove the temporary directory
    FileUtils.remove_dir(tmpDir, true)

    # Stop saving files to mini analysis
    #copyFileMiniAnalysis(resultFileName)
  end

  # Helper method to email uniqueness results
  def emailUniquenessResults(resultFileName)
    adaptorPlotFile = "AdaptorReadsDistribution.png"

    emailFrom    = "sol-pipe@bcm.edu"
    emailSubject = "Illumina Uniqueness Results"
    emailTo      = nil
    emailText    = nil

    obj = EmailHelper.new()
    emailTo = obj.getResultRecepientEmailList()

    resultFile = File.open(resultFileName, "r")
    emailText = resultFile.read()

    if !File::exist?(adaptorPlotFile) || !File::readable?(adaptorPlotFile) ||
        File::size(adaptorPlotFile) == 0
        obj.sendEmail(emailFrom, emailTo, emailSubject, emailText)
    else
      # Send the adaptor plot distribution as email attachment
      obj.sendEmailWithAttachment(emailFrom, emailTo, emailSubject, emailText, adaptorPlotFile)
    end
  end

  # Helper method to find sequence files for a given lane
  # Find Sequence files only of the format s_x_sequence.txt (fragment),
  # s_x_1_sequence.txt (read1), s_x_2_sequence.txt (read2).
  # Sort the filenames to feed the filenames to the java in the correct order
  # (read 1 before read2).
  def findSequenceFileNames(laneNum)
    sequenceFiles = Dir["s_" + laneNum.to_s + "*sequence.txt"]
    result = Array.new
    sequenceFiles.each do |file|
      if file.match(/s_\d_sequence.txt/) || file.match(/s_\d_1_sequence.txt/) ||
         file.match(/s_\d_2_sequence.txt/)
         result << file       
      end
    end
    result.sort!
    return result
  end

  # Helper method to copy resultFile to mini analysis
  def copyFileMiniAnalysis(fileName)
    currentDir = Dir.pwd
    miniDir    = currentDir.gsub(/Data.*$/, 'mini_analysis')
    puts "Creating mini_analysis directory"
    system("mkdir -p #{miniDir}")
    puts "Copying " + fileName + " to mini_analysis directory"
    system("cp #{fileName} #{miniDir}") 
  end

  # Helper method to upload uniqueness percentage to LIMS
  #TODO: Make upload part of another script (maybe helper)
  # and perform error detection if upload to LIMS fails
  def uploadResultsToLIMS(resultFile)
    limsUploadCmd = "perl /stornext/snfs5/next-gen/Illumina/ipipe/" +
                    "third_party/setIlluminaLaneStatus.pl " + @limsBarcode +
                    " ANALYSIS_FINISHED UNIQUE_PERCENT "

    foundUniquenessResult = false

    lines = IO.readlines(resultFile)

    lines.each do |line|
      if line.match(/\% Unique Reads/)
        foundUniquenessResult = true
        line.gsub!(/^\D+/, "")
        uniqPer = line.slice(/^[0-9\.]+/)
        puts uniqPer.to_s
        cmd = limsUploadCmd + uniqPer.to_s
        puts "Uploading uniqueness results"
        puts cmd
        `#{cmd}`
        return
      end
    end

    if foundUniquenessResult == false
      raise "Did not find uniqueness percentage"
    end
  end
end

obj = FindUniqueReads.new()
