#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'rubygems'
require 'hpricot'
require 'fileutils'
require 'net/smtp'
require 'PipelineHelper'

# Class to find the barcode for the GERALD directory
# For non-multiplexed lanes, it returns empty string as the barcode.
class FCBarcodeFinder

  # Class constructor
  def initialize()
    @barcode = ""
    @pipelineHelper = PipelineHelper.new
    @analysisLane = @pipelineHelper.findAnalysisLaneNumbers()
    @fcName       = @pipelineHelper.findFCName()
    puts @analysisLane.to_s
  end

  # Find the barcode for the current GERALD directory.
  # If no barcode, return an empty string

  # If the current GERALD directory lies under a numbered directory such as
  # 001, 002 etc, the barcode information is present in the Summary.xml file
  # However, if the current GERALD directory lies under "unknown" directory,
  # then, read the SampleSheet.csv and SamplesDirectories.csv. Find the barcode
  # that is present in SampleSheet.csv but missing from SamplesDirectories.csv
  # This is the barcode for the GERALD directory under "unknown" bucket.
  # If the lane is not multiplexed, return an empty string to indicate missing
  # barcode.
  def findBarcode()
    @barcode = findBarcodeInSummary()

    if @barcode == nil || @barcode.empty?()
      @barcode = findBarcodeFromCSV()
    end 
      return @barcode.to_s
  end

=begin
  # Given a valid barcode sequence, return the ID number used to identify
  # this barcode in LIMS
  def findTagID(barcode)
    if barcode == nil || barcode.empty?()
      return ""
    elsif barcode.eql?("CGATGT")
       return "ID02"
     elsif barcode.eql?("TGACCA")
       return "ID04"
     elsif barcode.eql?("ACAGTG")
       return "ID05"
     elsif barcode.eql?("GCCAAT")
       return "ID06"
     elsif barcode.eql?("CAGATC")
       return "ID07"
     elsif barcode.eql?("CTTGTA")
       return "ID12"
     else
       raise "Invalid barcode specified"
    end
  end
=end

  # Return the flowcell barcode for upload to LIMS
  def getBarcodeForLIMS()
    limsBarcode = @fcName + "-" + @analysisLane.to_s 
    findBarcode()

    if @barcode != nil && !@barcode.empty?()
      limsBarcode = limsBarcode + "-" + 
                    @pipelineHelper.findBarcodeTagID(@barcode.to_s)
    end
    return limsBarcode.to_s
  end

  private
  # Helper method to find the barcode tag from the Summary.xml file. Barcode
  # tag is present in the summary files whose GERALD directories are not
  # under the "unknown" directory, i.e. directories 001, 002 ...
  def findBarcodeInSummary()
    barcode = ""

    doc = Hpricot::XML(open('Summary.xml'))
    (doc/:'Samples/Lane').each do|lane|
      laneNumber = (lane/'laneNumber').inner_html
      bcode      = (lane/'barcode').inner_html
      puts "Lane Number : " + laneNumber.to_s + " Barcode : " + bcode.to_s 

      if laneNumber.to_s.eql?(@analysisLane)
        barcode = bcode
      end
    end
    return barcode
  end

  # Helper method to find the barcode when the current GERALD directory lies
  # under the "unknown" directory
  def findBarcodeFromCSV()
    puts Dir.pwd
    sampleSheetPath = "../../../SampleSheet.csv"
    samplesDirPath  = "../../SamplesDirectories.csv"
    barcodeHash     = Hash.new

    if File::exist?(sampleSheetPath) &&
       File::exist?(samplesDirPath)

       lines1 = IO.readlines(sampleSheetPath)
       lines2 = IO.readlines(samplesDirPath)

       lines2.each do |line|
         tokens = line.split(",")
         
         if tokens[1].to_s.eql?(@analysisLane.to_s)
       #    puts "Adding : " + tokens[4] + " to hashtable"
           barcodeHash.store(tokens[4], "")
         end
       end

      lines1.each do |line|
        tokens = line.split(",")

        if tokens[1].to_s.eql?(@analysisLane.to_s) &&
           !barcodeHash.has_key?(tokens[4])
           return tokens[4].to_s
        end
      end     
      return ""
    else
      # The flowcell is not barcoded. Return an empty string
      return ""
    end
  end
end

#__END__
obj = FCBarcodeFinder.new
puts "LIMS barcode = " + obj.getBarcodeForLIMS()
