#!/usr/bin/ruby

# Class to create a mapping between the barcode tag IDs and the actual barcode
# sequences. 
# Author Nirav Shah niravs@bcm.edu

class  BarcodeDefinitionBuilder
  def initialize(outputDirectory, barcodeTagList)
    writeBarcodeMapFile(outputDirectory, barcodeTagList)
  end

  private
  # Write a list of barcode names and the sequences in the specified output
  # directory, (usually the basecalls directory of the given flowcell).
  # This is to allow different sets of sequences to be written for different
  # flowcells to let mix and match of barcodes with different lengths. 
  # TODO: Add code to fix the short sequences to become longer sequences
  def writeBarcodeMapFile(outputDirectory, barcodeTagList)
    outputFileName = getBarcodeDefinitionFileName(outputDirectory)
    outputFile = File.open(outputFileName, "w")

    barcodeSequences = Array.new

    barcodeTagMap = Hash.new

    barcodeTagList.each do |barcodeTagName|
      if barcodeTagName.match(/ID/)
         bTag = barcodeTagName.gsub(/^\d-/, "")
         barcodeTagMap[bTag] = bTag
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
      if barcodeTagMap.has_key?(barcodeLabel)
         outputFile.puts tokens[0].strip + "," + tokens[1].strip
      end
    end
    outputFile.close
  end

  # Return the filename where the barcode tag, sequence mapping information
  # should be stored.
  def getBarcodeDefinitionFileName(outputDirectory)
    outputFileName = outputDirectory + "/barcode_definition.txt"
    return outputFileName.to_s
  end
end
