#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'PipelineHelper'
require 'FCBarcodeFinder'

class BWAMapStats
  def initialize(bamFileName)
    @bamFile    = bamFileName
    @outputFile = "BWA_Map_Stats.txt"
    @helper     = PipelineHelper.new
    begin
      obj         = FCBarcodeFinder.new
      @fcBarcode  = obj.getBarcodeForLIMS()
    rescue
      @fcBarcode = "unknown"
    end
  end

  def process()
    statsJarPath = "/stornext/snfs5/next-gen/Illumina/ipipe/java/" +
                   "BAMAnalyzer.jar"
    cmd = "java -Xmx8G -jar " + statsJarPath + " " + @bamFile + " > " +
          @outputFile
    `#{cmd}`

    # Email the results
    emailResults()
#    uploadToLIMS()
  end

  # Method to email the mapping results
  def emailResults()
    resultFile = File.open(@outputFile, "r")
    lines = resultFile.read()
    lines << "\r\n"
    lines << "File-system Path : " 
    lines << Dir.pwd + "/" + @bamFile.to_s

    emailSubject = "Illumina BAM Alignment Results : Flowcell " + @fcBarcode.to_s

   # to = [ "dc12@bcm.edu", "niravs@bcm.edu" ]
    to = [ "dc12@bcm.edu", "niravs@bcm.edu", "yhan@bcm.edu", "fongeri@bcm.edu",
           "javaid@bcm.edu", "yw14@bcm.edu", "jgreid@bcm.edu", "cbuhay@bcm.edu",
           "ahawes@bcm.edu" ]
    @helper.sendEmail("sol-pipe@bcm.edu", to, emailSubject, lines)
  end

  def uploadToLIMS()
    limsScript = "/stornext/snfs5/next-gen/Illumina/ipipe/third_party/" +
                  "setIlluminaLaneStatus.pl" 
    baseCmd = "perl " + limsScript + " " + @fcBarcode + " ANALYSIS_FINISHED READ"

    # Alignment percentage array
    mapPercent   = Array.new
    errorPercent = Array.new

    IO.foreach(@outputFile) do |line|
      if line.match(/\% Mapped Reads/)
        temp = line.gsub(/\% Mapped Reads\s+:\s+/, "")
        temp.strip!
        temp.gsub!(/\%$/, "")
        mapPercent << temp
      elsif line.match(/Mismatch Percentage/)
        temp = line.gsub(/Mismatch Percentage\s+:\s+/, "")
        temp.strip!
        temp.gsub!(/\%$/, "")
        errorPercent << temp
      end
    end

    uploadCmdRead1 = baseCmd + " 1 PERCENT_ALIGN_PF " + mapPercent[0].to_s + 
                     " PERCENT_ERROR_RATE_PF " + errorPercent[0].to_s
    puts uploadCmdRead1
    `#{uploadCmdRead1}`

    if mapPercent.length == 2
      uploadCmdRead2 = baseCmd + " 2 PERCENT_ALIGN_PF " + mapPercent[1].to_s + 
                      " PERCENT_ERROR_RATE_PF " + errorPercent[1].to_s
      puts uploadCmdRead2
      `#{uploadCmdRead2}`
    end
  end

  private

  @bamFile     = nil   # BAM File to process for stats calculations
  @outputFile  = ""    # Name of the output file
  @helper      = nil   # PipelineHelper instance
  @fcName      = ""    # Flowcell name
end

obj = BWAMapStats.new(ARGV[0]) 
obj.process()
