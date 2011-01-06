#!/usr/bin/ruby
require 'rubygems'
require 'hpricot'
require 'fileutils'
require 'net/smtp'

# This class encapsulates common routines required by other 
# pipeline scripts
class PipelineHelper

  # Method to read config.txt and return lanes for which
  # analysis was performed
  def findAnalysisLaneNumbers()
    analysisLanes = ""
    configFileLines = IO.readlines("config.txt")
    idx=0

    while idx < configFileLines.size do
      if ( configFileLines[idx] =~ /^[1-8]+:ANALYSIS/) &&
         !(configFileLines[idx] =~ /none/) then
        temp = configFileLines[idx].index(":") - 1
        analysisLanes = configFileLines[idx][0..temp]
      end
      idx += 1
    end
    return analysisLanes
  end

  # Method to find flowcell name from Summary.xml
  def findFCName()
    doc = Hpricot::XML(open('Summary.xml'))
    fcName = ""
    (doc/:'ChipSummary').each do|summary|
      runFolder = (summary/'RunFolder').inner_html

      run = runFolder[/([a-zA-Z0-9]+)$/]

      if run.match(/^FC/)
        fcName = run.slice(2, run.size)
      else
         fcName = run
      end
    end
    # For HiSeqs, a flowcell is prefixed with letter "A" or "B".
    # We remove this prefix from the reduced flowcell name, since
    # a flowcell name is entered without the prefix letter in LIMS.
    # For GA2, there is no change.
    fcName.slice!(/^[a-zA-Z]/)
    return fcName
  end

  # This helper method searches for flowcell in list of volumes and returns
  # the path of the flowcell including it's directory.
  # If it does not find the path for flowcell, it aborts with an exception
    def findFCPath(fcName)
      fcPath = ""

      # This represents location where to search for flowcell
      rootDir = "/stornext/snfs0/next-gen/Illumina/Instruments"

      # Populate an array with list of volumes where this flowcell
      # is expected to be found
      parentDir = Array.new
      parentDir << rootDir + "/EAS034"
      parentDir << rootDir + "/EAS376"
      parentDir << rootDir + "/700142"
      parentDir << rootDir + "/700166"
      parentDir << rootDir + "/700580"
      parentDir << rootDir + "/700601"

      parentDir.each{ |path|
        if File::exist?(path + "/" + fcName) &&
           File::directory?(path + "/" + fcName)
           fcPath = path + "/" + fcName
        end
      }

      if fcPath.eql?("")
        puts "Error : Did not find path for flowcell : " + fcName
        raise "Error in finding path for flowcell : " + fcName
      end
      return fcPath.to_s
    end

  # Helper method to locate the basecalls (bustard) directory for the
  # specified flowcell
  def findBaseCallsDir(fcName)
    fcPath = ""

    # This represents directory hierarchy where GERALD directory
    # gets created.
    baseCallsDirPaths = Array.new
    baseCallsDirPaths << "Data/Intensities/BaseCalls"
    baseCallsDirPaths << "BCLtoQSEQ"
    
    fcPath = findFCPath(fcName)
    
    baseCallsDirPaths.each{ |bcPath|
      if File::exist?(fcPath + "/" + bcPath) &&
         File::directory?(fcPath + "/" + bcPath)
         return fcPath.to_s + "/" + bcPath.to_s
      end
    }
    raise "Did not find Base calls directory for flowcell : " + fcName
  end

  # Helper method that returns true if the specified flowcell is HiSeq.
  # False if GA2.
  def isFCHiSeq(fcName)
    # If the name of the flowcell contains the string "EAS034" or "EAS376
    # then it is GA2 flowcell, else it is HiSeq flowcell
    if !fcName.match("EAS034") && !fcName.match("EAS376")
      return true
    else
      return false
    end
  end

  # Given a valid barcode sequence, return the ID number used to identify
  # this barcode in LIMS
  def findBarcodeTagID(barcode)
    barcodeLabel = ""
    if barcode == nil || barcode.empty?()
      return ""
    end
    lines = IO.readlines("/stornext/snfs5/next-gen/Illumina/ipipe/lib/barcode_label.txt")

    lines.each do |line|
      tokens = line.split(",")
      if tokens[1].strip.eql?(barcode)
         barcodeLabel = tokens[0].strip
      end
    end

    if barcodeLabel.empty?()
      raise "Invalid barcode specified"
    else
      return barcodeLabel
    end
  end

  # Given a valid barcode tag, return the sequence for this barcode
  # this barcode in LIMS
  def findBarcodeSequence(barcodeTag)
    barcode = ""
    if barcodeTag == nil || barcodeTag.empty?()
      return ""
    end

    lines = IO.readlines("/stornext/snfs5/next-gen/Illumina/ipipe/lib/barcode_label.txt")

    lines.each do |line|
      tokens = line.split(",")
      if tokens[0].strip.eql?(barcodeTag)
         barcode = tokens[1].strip
      end
    end

    if barcode.empty?()
      raise "Invalid barcode tag specified"
    else
      return barcode
    end
  end

  # Method to send an email
  # Parameter "to" is an array of email addresses separated by commas
  def sendEmail(from, to, subject, message)
     toMail = ""
     to.each { |x| toMail= toMail + ",#{x}" }

msg = <<END_OF_MESSAGE
From: <#{from}>
To: <#{toMail}>
Subject: #{subject}

#{message}
END_OF_MESSAGE

      Net::SMTP.start('smtp.bcm.tmc.edu') do |smtp|
      smtp.send_message msg, from, to
    end
  end
end

