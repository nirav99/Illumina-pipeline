#!/usr/bin/ruby

require 'fileutils'
require 'PipelineHelper'

# Class that encapsulates the experiment directory - where corresponding
# GERALD directory(ies) are created.
class ExptDir
  def initialize(fcName)
    @fcName         = fcName
    @pipelineHelper = PipelineHelper.new
    @baseCallsDir   = @pipelineHelper.findBaseCallsDir(@fcName)
    @isFCMuxed      = FCMultiplexed?() # If FC is multiplexed (bar-coded)
    @barcodeSeq     = ""               # Barcode sequence
  end

  # Method to retrieve experiment directory based on lane barcode of the FC
  def getExptDir(laneBarcode)
    if !laneBarcodeSyntaxValid?(laneBarcode)
      raise "Exception : Invalid barcode " + laneBarcode.to_s + " specified"
    end

    # if the Flowcell is not multiplexed, return the basecalls dir as expt dir
    if !@isFCMuxed
      return @baseCallsDir.to_s
    end
   
    # Flowcell is multiplexed
    @barcodeSeq = getIndexSequence(laneBarcode)

    if !laneBarcodeValidInSamplesCSV?(laneBarcode)
      raise "Exception : Lane Barcode " + laneBarcode + " is inconsistent with CSV"
    end

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
  def laneBarcodeSyntaxValid?(lane)
    if !laneIndexed?(lane)
      if lane.to_s.match(/^[1-8]$/)
         return true
      else
         return false
      end
    else
      if !@isFCMuxed # Lane is indexed, but FC is not multiplexed => invalid
        puts "Invalid lane barcode. Flowcell is not multiplexed"
        return false
      end
      
      if lane.match(/^[1-8]-ID[01]\d/) || lane.match(/^[1-8]-IDMB\d\d/) ||
         lane.match(/^[1-8]-IDMB\d/)
         return true
      else
         return false
      end
    end 
  end

  # Return true if lane is indexed, false otherwise
  def laneIndexed?(lane)
    if lane.to_s.match(/^[1-8]-ID/)
      return true
    else
      return false
    end
  end

  # Return the index sequence for the lane barcode
  def getIndexSequence(laneBarcode)
    if !laneIndexed?(laneBarcode)
      puts "LANE NOT INDEXED"
      return ""
    else
      tag = laneBarcode.gsub(/^[1-8]-ID/, "")
      puts "TAG = " + tag
      return @pipelineHelper.findBarcodeSequence("ID" + tag.to_s) 
    end
  end

  # Method to return the correct directory bin for the specified lane barcode
  def getDirectoryBin(laneBarcode)
    binListFile = @baseCallsDir + "/Demultiplexed/SamplesDirectories.csv"
    resultPath  = @baseCallsDir + "/Demultiplexed/"
    binValue    = nil

    indexSequence = getIndexSequence(laneBarcode)

    puts "LANE BARCODE   = " + laneBarcode.to_s
    puts "INDEX SEQUENCE = " + indexSequence.to_s

    if !File::exist?(binListFile)
      raise "Error : Did not find File : " + binListFile
    end
  
    laneNumber = laneBarcode.slice(0).chr.to_s
    lines = IO.readlines(binListFile)
     
    lines.each do |line|
      tokens = line.split(",")  

      if tokens[1].to_s.eql?(laneNumber.to_s) && tokens[4].eql?(indexSequence)
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
  def laneBarcodeValidInSamplesCSV?(lane)
    sampleSheet       = "SampleSheet.csv"
    laneFoundInCSV    = false
    barcodeFoundInCSV = false

    if !@isFCMuxed
      return true
    end

    if !File::exist?(@baseCallsDir + "/" + sampleSheet)
      raise "Error : Did not find Sample Sheet : " + sampleSheet + " in " + @baseCallsDir
    end

    laneNumber = lane.slice(0).chr.to_s
    lines = IO.readlines(@baseCallsDir + "/" + sampleSheet) 
   
    lines.each do |line|
      tokens = line.split(",")
      if tokens[1].to_s.eql?(laneNumber.to_s)
        laneFoundInCSV = true
      end
      if @barcodeSeq != nil && !@barcodeSeq.empty?() && tokens[4].to_s.eql?(@barcodeSeq)
        barcodeFoundInCSV = true
      end
    end

    if laneFoundInCSV && !barcodeFoundInCSV
      puts "Error : Invalid Lane barcode " + lane
      puts " Lane Number present in CSV but barcode " + @barcodeSeq + " is absent from CSV"
      return false
    elsif barcodeFoundInCSV && !laneFoundInCSV
      puts "Error : Lane " + laneNumber.to_s + " is not multiplexed as per CSV"
      return false
    else
      return true
    end
  end
end

__END__
begin
obj = ExptDir.new("110413_SN166_0177_BC0117ABXX")
#obj = ExptDir.new("101109_SN166_0149_B806DTABXX")
#obj.getExptDir("1-ID06")
puts obj.getExptDir("8-IDMB38")
#obj.getExptDir("1-ID01")
rescue Exception => e
  puts e.message
  puts e.backtrace.inspect
end
