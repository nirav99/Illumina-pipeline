#!/usr/bin/ruby
require 'rubygems'
require 'hpricot'
require 'fileutils'
#require 'net/smtp'

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

  # Method to take a complete fc name and return the portion used for
  # interacting with LIMS
  def formatFlowcellNameForLIMS(fcName)
    puts "FOUND FC NAME = " + fcName.to_s
    limsFCName = fcName.slice(/([a-zA-Z0-9]+)$/)

    if limsFCName.match(/^FC/)
      limsFCName.gsub!(/^FC/, "")
    end

    # For HiSeqs, a flowcell is prefixed with letter "A" or "B".
    # We remove this prefix from the reduced flowcell name, since
    # a flowcell name is entered without the prefix letter in LIMS.
    # For GA2, there is no change.
    limsFCName.slice!(/^[a-zA-Z]/)
    return limsFCName.to_s
  end

  # This helper method searches for flowcell in list of volumes and returns
  # the path of the flowcell including it's directory.
  # If it does not find the path for flowcell, it aborts with an exception
    def findFCPath(fcName)
      fcPath    = ""
      parentDir = Array.new

      # This represents location where to search for flowcell
      rootDir    = "/stornext/snfs0/next-gen/Illumina/Instruments"

      dirEntries = Dir.entries(rootDir)

      # In the rootDir of the data copied over from the sequencers, find 
      # directories corresponding to each sequencer and populate the 
      # parentDir array
      dirEntries.each do |dirEntry|
        if !dirEntry.eql?(".") && !dirEntry.eql?("..") &&
           File::directory?(rootDir + "/" + dirEntry.to_s)
           parentDir << rootDir + "/" + dirEntry.to_s
        end
      end

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

    if File.dirname(__FILE__).eql?(".")
      barcodeLabelFile = "../config/barcode_label.txt"
    else
      barcodeLabelFile = File.dirname(File.dirname(__FILE__)) +
                         "/config/barcode_label.txt"
    end

    lines = IO.readlines(barcodeLabelFile)

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

    puts "Value of dirname = " + File.dirname(__FILE__).to_s
    barcodeLabelFile = "/stornext/snfs5/next-gen/Illumina/ipipe/config//barcode_label.txt"
    puts "Looking for barcode labels in : " + barcodeLabelFile

    lines = IO.readlines(barcodeLabelFile)

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
end
