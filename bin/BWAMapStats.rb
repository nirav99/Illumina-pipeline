#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'PipelineHelper'
require 'FCBarcodeFinder'
require 'BWAParams'
require 'EmailHelper'

class BWAMapStats
  def initialize(bamFileName)
    @bamFile    = bamFileName
    @outputFile = "BWA_Map_Stats.txt"
    @fcBarcode  = ""
    @library    = ""
    begin
      obj          = FCBarcodeFinder.new
      @fcBarcode   = obj.getBarcodeForLIMS()
      configParams = BWAParams.new()
      configParams.loadFromFile()
      @library     = configParams.getLibraryName()
    rescue
      if @fcBarcode.empty?()
         @fcBarcode = "unknown"
      end
    end
     
  end

  def process()
    statsJarPath = "/stornext/snfs5/next-gen/Illumina/ipipe/java/" +
                   "BAMAnalyzer.jar"
    cmd = "java -Xmx8G -jar " + statsJarPath + " I=" + @bamFile + " > " +
          @outputFile
    `#{cmd}`

    # Email the results
  #  emailResults()
  end

  # Method to email the mapping results
  def emailResults()
    resultFile = File.open(@outputFile, "r")
    lines = resultFile.read()
    lines << "\r\n"
    lines << "File-system Path : " 
    lines << Dir.pwd + "/" + @bamFile.to_s

    # Fill in the fields for sending the email
    emailSubject = "Illumina Alignment Results : Flowcell " + @fcBarcode.to_s

    if @library != nil && !@library.empty?
       emailSubject = emailSubject + " Library : " + @library.to_s
    end

    from = "sol-pipe@bcm.edu" 

    obj = EmailHelper.new()

    # Find the list of people to send the email to
    # In the file ../config/email_recepients.txt, use the list corresponding to
    # the label EMAIL_RESULTS
    to = obj.getResultRecepientEmailList()

    # Send the email
    obj.sendEmail(from, to, emailSubject, lines)
  end

  private

  @bamFile     = nil   # BAM File to process for stats calculations
  @outputFile  = ""    # Name of the output file
  @fcName      = ""    # Flowcell name
end

obj = BWAMapStats.new(ARGV[0]) 
obj.process()
