#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'PipelineHelper'
require 'FCBarcodeFinder'
require 'BWAParams'
require 'EmailHelper'

# Class to email analysis results
class ResultMailer
  def initialize()
    @bamFile        = ""
    @emailText      = ""
    @emailSubject   = ""
    @attachments    = nil
    buildEmailSubject()
    buildEmailText()
    findAttachmentFiles()
  end

  def emailResults()
    from = "sol-pipe@bcm.edu"

    obj = EmailHelper.new()

    # Find the list of people to send the email to
    # In the file ../config/email_recepients.txt, use the list corresponding to
    # the label EMAIL_RESULTS
    to = obj.getResultRecepientEmailList()

    if @attachments != nil && @attachments.length > 0
      obj.sendEmailWithAttachment(from, to, @emailSubject, @emailText, @attachments)
    else
      obj.sendEmail(from, to, @emailSubject, @emailText)
    end
  end

  private
  def buildEmailSubject()
    begin
      obj          = FCBarcodeFinder.new
      fcBarcode    = obj.getBarcodeForLIMS()
      configParams = BWAParams.new()
      configParams.loadFromFile()
      library      = configParams.getLibraryName()
    rescue
      if fcBarcode.empty?()
        fcBarcode = "unknown"
      end
    end

     # Fill in the fields for sending the email
    @emailSubject = "Illumina Alignment Results : Flowcell " + fcBarcode.to_s

    if library != nil && !library.empty?
       @emailSubject = @emailSubject + " Library : " + library.to_s
    end
  end

  def buildEmailText()
    uniqText = ""
    mappingText = nil

    uniquenessResult = Dir["Uniqueness_*"]

    puts "UniquenessResult files : " + uniquenessResult.to_s
    if uniquenessResult != nil && uniquenessResult.length > 0
      uniqText = IO.readlines(uniquenessResult[0])
    end

    if File::exist?("BWA_Map_Stats.txt")
      mappingText = IO.readlines("BWA_Map_Stats.txt")
      @emailText = mappingText
      @emailText <<  "\r\n\r\n"
    end

    @emailText << "Sequence Quality Analysis"
    @emailText << "\r\n\r\n"
    @emailText << uniqText
    @emailText << "\r\n\r\n"
    @emailText << "File System Path : " + Dir.pwd.to_s
  end

  # Find all png files in the directory. For now, don't discover a file named
  # DistributionOfN.png. This might be changed in future.
  def findAttachmentFiles()
    @attachments = Array.new
    pngFiles     = Dir["*.png"]

    pngFiles.each do |file|
#      if !file.match(/DistributionOfN.png/)
        @attachments << file
#      end
    end
  end
end

obj = ResultMailer.new()
obj.emailResults()
