#!/usr/bin/ruby

require 'fileutils'
require 'PipelineHelper'

# Class that encapsulates the experiment directory - where corresponding
# GERALD directory(ies) are created.
# Author - Nirav Shah niravs@bcm.edu
class ExptDir
  def initialize(fcName)
    @fcName         = fcName
    @pipelineHelper = PipelineHelper.new
    @baseCallsDir   = @pipelineHelper.findBaseCallsDir(@fcName)
    @isFCMuxed      = FCMultiplexed?() # If FC is multiplexed (barcoded)
  end

  # Method to retrieve experiment directory based on lane barcode of the FC
  def getExptDir(laneBarcode)
    # Validate that the lane barcode is syntactically valid
    if !laneBarcodeSyntaxValid?(laneBarcode)
      raise "Exception : Invalid barcode " + laneBarcode.to_s + " specified"
    end

    # Since the lane barcode is valid, and the flowcell is not multiplexed,
    # return the basecalls directory as the experiement directory
    if !@isFCMuxed
      return @baseCallsDir.to_s
    end
   
    # Since the flowcell is multiplexed, validate that the lane barcode is
    # consistent with the information in SampleSheet.csv
    if !laneBarcodeValidInSamplesCSV?(laneBarcode)
      raise "Exception : Lane Barcode " + laneBarcode + " is inconsistent with CSV"
    end

    # All is valid, return the directory bin for the given lane barcode 
    return getDirectoryBin(laneBarcode)
  end
 
  private
  # Method to check if this flowcell is multiplexed
  # If yes return true, else false
  def FCMultiplexed?()
    demuxDir = @baseCallsDir + "/Demultiplexed"
    if File::exist?(demuxDir) && File::directory?(demuxDir)
      return true
    else
      return false 
    end
  end

  # Method to check if lane barcode has valid syntax
  # If yes, return true, else return false
  def laneBarcodeSyntaxValid?(laneBarcode)
    # If the flowcell is not multiplexed, lane barcode should be just the lane
    # number from 1 through 8. If that is not so, return false to indicate the
    # error
    if !@isFCMuxed && !laneBarcode.match(/^[1-8]$/) 
       return false
    # If the flowcell is multiplexed, the lane barcode can have one of the
    # following formats, just lane number (non-multiplexed lane), X-IDYY 
    # or X-IDMBY or X-IDMBYY
    elsif laneBarcode.match(/^[1-8]$/) || laneBarcode.match(/^[1-8]-ID[01]\d$/) ||
          laneBarcode.match(/^[1-8]-IDMB\d$/) || laneBarcode.match(/^[1-8]-IDMB\d\d$/)
       return true
    else
      return false
    end
  end

  # Method to return the correct directory bin for the specified lane barcode
  def getDirectoryBin(laneBarcode)
    binListFile = @baseCallsDir + "/Demultiplexed/SamplesDirectories.csv"
    resultPath  = @baseCallsDir + "/Demultiplexed/"
    binValue    = nil

    if !File::exist?(binListFile)
      raise "Error : Did not find File : " + binListFile
    end
  
    laneNumber = laneBarcode.slice(0).chr.to_s
    barcodeTag = laneBarcode.gsub(/^\d-/, "")

    lines = IO.readlines(binListFile)
     
    lines.each do |line|
      tokens = line.split(",")  

      if tokens[1].to_s.eql?(laneNumber.to_s) && tokens[5].eql?(barcodeTag)
        binValue = tokens[9]
        break
      end
    end

    if binValue == nil
      binValue = "unknown"
    end
 
    resultPath = resultPath + binValue
    resultPath.strip!
    if File::exist?(resultPath) && File::directory?(resultPath)
      return resultPath
    else
      raise "Error : Expected BaseCalls Dir : " + resultPath + " does not exist"
    end
  end

  # Check if the lane barcode is valid as per the information in SampleSheet.csv
  # If yes, return true, else false
  def laneBarcodeValidInSamplesCSV?(laneBarcode)
    laneNumber = laneBarcode.slice(0).chr.to_s
    barcodeTag = ""

    if laneBarcode.match(/-ID/)
      barcodeTag = laneBarcode.gsub(/\d-/, "")
    end

    sampleSheet       = "SampleSheet.csv"
    laneFoundInCSV    = false
    barcodeFoundInCSV = false

    # This flowcell is multiplexed, so it must have a SampleSheet.csv file in
    # its basecalls directory. Validate that this file exists
    if !File::exist?(@baseCallsDir + "/" + sampleSheet)
      raise "Error : Did not find Sample Sheet : " + sampleSheet + " in " + @baseCallsDir
    end

    # Read the SampleSheet.csv
    lines = IO.readlines(@baseCallsDir + "/" + sampleSheet)

    lines.each do |line|
      tokens = line.split(",")

      if tokens[1].to_s.eql?(laneNumber.to_s)
        laneFoundInCSV = true
        if tokens[5].to_s.eql?(barcodeTag)
           # Both the lane and the barcode tag are found in SampleSheet.csv, so
           # laneBarcode is valid. Return true.
           return true
        end
      end
    end

    if barcodeTag.empty?() && !laneFoundInCSV
      # This lane was not multiplexed, so barcodeTag is empty, and the lane does
      # not have an entry in SampleSheet.csv. Hence, return true to indicate
      # valid lane barcode.
      return true
    else
      # Return false. The specified lane barcode is not valid.
      return false
    end
  end
end

__END__
begin
obj = ExptDir.new("110413_SN166_0177_BC0117ABXX")
puts obj.getExptDir("7-IDMB44")
#obj.getExptDir("1-ID01")
rescue Exception => e
  puts e.message
  puts e.backtrace.inspect
end
