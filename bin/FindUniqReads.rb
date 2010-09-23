#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'rubygems'
require 'hpricot'
require 'fileutils'
require 'net/smtp'
require 'PipelineHelper'

#This class is a wrapper for SlxUniqueness.jar to find unique reads.
#It works on per-lane basis only.
class FindUniqueReads
  def initialize()
    jarName = "/stornext/snfs5/next-gen/Illumina/ipipe/java/SlxUniqueness.jar"
    @lanes   = ""  # Lanes to consider for running uniqueness
    @fcName  = ""
    javaVM  = "-Xmx8G" # Specifies maximum memory size of JVM
    @coreCmd = "java " + javaVM + " -jar " + jarName
    @helper  = PipelineHelper.new

    begin
      #findLaneNumbers()
      #findFCName()
      @lanes  = @helper.findAnalysisLaneNumbers()
      @fcName = @helper.findFCName()
      findUniqueness()
    rescue Exception => e
      puts e.message
      puts e.backtrace.inspect
      exit -1
    end
  end

  private

  def findUniqueness()
    @lanes.each_byte do |lane|
      puts "Generating Uniqueness for lane : " + lane.chr
      fileNames = findSequenceFileNames(lane.chr)
      buildJarCommand(lane.chr, fileNames)
    end
  end

  def buildJarCommand(lane, fileNames)
    resultFileName = "Uniqueness_" + @fcName + "_" + lane + ".txt"

    # Create temp directory
    tmpDir = "tmp_" + lane
    FileUtils.mkdir(tmpDir)

    # Select analysis as fragment or paired
    if fileNames.length == 2
      analysisMode = "paired"
    else
      analysisMode = "fragment"
    end
    cmd = @coreCmd + " AnalysisMode=" + analysisMode + " TmpDir=" + tmpDir

    fileNames.each do |fname|
      cmd = cmd + " Input=" + fname
    end
    puts cmd

    resultFile = File.new(resultFileName, "w")
    resultFile.write("Flowcell Name : " + @fcName + " Lane Number : " + lane)
    resultFile.close()
#    resultFile.write("")
    puts "Computing Uniqueness Results"
    cmd = cmd + " >> " + resultFileName
    `#{cmd}`

    resultFile = File.open(resultFileName, "r")
    lines = resultFile.read()

    to = [ "dc12@bcm.edu", "niravs@bcm.edu", "yhan@bcm.edu", "english@bcm.edu", 
           "fongeri@bcm.edu", "javaid@bcm.edu", "yw14@bcm.edu", "jgreid@bcm.edu" ]
    @helper.sendEmail("sol-pipe@bcm.edu", to, "Illumina Uniqueness Results", lines)
    puts "Finished Computing Uniqueness Results for lane : " + lane

    # Upload uniqueness results to LIMS
    uploadResultsToLIMS(resultFileName, lane)

    FileUtils.remove_dir(tmpDir, true)
    copyFileMiniAnalysis(resultFileName)
  end

  # Helper method to find sequence files for a given lane
  def findSequenceFileNames(laneNum)
    return Dir["s_" + laneNum + "*sequence.txt"]
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
  def uploadResultsToLIMS(resultFile, laneNum)
    limsUploadCmd = "perl /stornext/snfs5/next-gen/Illumina/ipipe/" +
                    "third_party/setIlluminaLaneStatus.pl " + @fcName +
                    "-" + laneNum.to_s + " ANALYSIS_FINISHED " +
                    "UNIQUE_PERCENT "

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
