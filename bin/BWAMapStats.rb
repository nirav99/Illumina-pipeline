#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'PipelineHelper'
require 'FCBarcodeFinder'
require 'BWAParams'

class BWAMapStats
  def initialize(bamFileName)
    @bamFile    = bamFileName
    @outputFile = "BWA_Map_Stats.txt"
    @helper     = PipelineHelper.new
    @fcBarcode  = ""
    @library    = ""
    begin
      obj          = FCBarcodeFinder.new
      @fcBarcode   = obj.getBarcodeForLIMS()
      configParams = BWAParams.new()
      configParams.loadFromFile()
      @library     = configParams.getLibraryName()
    rescue
      puts "Rescued exception"
      if @fcBarcode.empty?()
         @fcBarcode = "unknown"
      end
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
  end

  # Method to email the mapping results
  def emailResults()
    resultFile = File.open(@outputFile, "r")
    lines = resultFile.read()
    lines << "\r\n"
    lines << "File-system Path : " 
    lines << Dir.pwd + "/" + @bamFile.to_s

    emailSubject = "Illumina Alignment Results : Flowcell " + @fcBarcode.to_s
    
    if @library != nil && !@library.empty?
       emailSubject = emailSubject + " Library : " + @library.to_s
    end

    to = [ "dc12@bcm.edu", "niravs@bcm.edu", "yhan@bcm.edu", "fongeri@bcm.edu", "pc2@bcm.edu", 
           "javaid@bcm.edu", "jgreid@bcm.edu", "cbuhay@bcm.edu", "ahawes@bcm.edu" ]
    @helper.sendEmail("sol-pipe@bcm.edu", to, emailSubject, lines)
  end

  private

  @bamFile     = nil   # BAM File to process for stats calculations
  @outputFile  = ""    # Name of the output file
  @helper      = nil   # PipelineHelper instance
  @fcName      = ""    # Flowcell name
end

obj = BWAMapStats.new(ARGV[0]) 
obj.process()
