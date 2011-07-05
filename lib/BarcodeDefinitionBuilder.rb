#!/usr/bin/ruby

# Class to create a mapping between the barcode tag IDs and the actual barcode
# sequences. 
# Author Nirav Shah niravs@bcm.edu

class  BarcodeDefinitionBuilder
  def initialize()
  end

  # Write a list of barcode names and the sequences in the specified output
  # directory, (usually the basecalls directory of the given flowcell).
  # This is to allow different sets of sequences to be written for different
  # flowcells to let mix and match of barcodes with different lengths. 
  # Shorter sequences are padded with additional characters to make all the
  # sequence lengths consistent.
  def writeBarcodeMapFile(outputDirectory, barcodeTagList)
    # To check if barcodes of different lengths are mixed
    minSeqLength = 10000000
    maxSeqLength = 0
    padding      = ""

    outputFileName = getBarcodeDefinitionFileName(outputDirectory)
    outputFile = File.open(outputFileName, "w")
    
    barcodeTagMap = Hash.new

    barcodeTagList.each do |barcodeTagName|
      if barcodeTagName.match(/ID/)
         bTag = barcodeTagName.gsub(/^\d-/, "")
         barcodeTagMap[bTag] = nil
      end
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
      barcodeLabel = tokens[0].strip
      barcodeSeq   = tokens[1].strip
      if barcodeTagMap.has_key?(barcodeLabel)
         barcodeTagMap[barcodeLabel] = barcodeSeq

         if barcodeSeq.length.to_i < minSeqLength.to_i
            minSeqLength = barcodeSeq.length
         end

         if barcodeSeq.length.to_i > maxSeqLength.to_i
            maxSeqLength = barcodeSeq.length
         end
      end
    end

    if (maxSeqLength - minSeqLength) == 3
       padding = "CTC"
    end

    # Write all the tag name, sequence pairs to the output file
    barcodeTagMap.each do |key, value|
      result = key.strip + "," + value.strip
      if value.length == minSeqLength
         result = result + padding
      end 
      outputFile.puts result
    end
    outputFile.close
  end

  # Given a valid barcode tag, return the sequence for this barcode
  def findBarcodeSequence(outputDirectory, barcodeTag)
    barcode = ""
    if barcodeTag == nil || barcodeTag.empty?()
      return ""
    end

    barcodeLabelFile = getBarcodeDefinitionFileName(outputDirectory)
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

  private
  # Return the filename where the barcode tag, sequence mapping information
  # should be stored.
  def getBarcodeDefinitionFileName(outputDirectory)
    outputFileName = outputDirectory + "/barcode_definition.txt"
    return outputFileName.to_s
  end
end
