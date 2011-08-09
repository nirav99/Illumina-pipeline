#!/usr/bin/ruby

require 'rubygems'
require 'hpricot'

# Class to parse the flowcell definition XML and retrive the fields necessary
# for the analysis.
# Author Nirav Shah niravs@bcm.edu
class LaneAnalysisInfo
  def initialize(fcDefnXML, laneBarcode)
    # Initialize the fields required for analysis to default values
    @readLength      = 0
    @chipDesign      = nil
    @refPath         = "sequence"
    @sampleName      = nil
    @libraryName     = nil
    @fcType          = ""

    parseFieldsFromXML(fcDefnXML, laneBarcode)
  end

  # Get methods to retrieve values of various fields
  def getReadLength()
    return @readLength
  end

  def getFlowcellType()
    return @fcType
  end

  def getReferencePath()
    return @refPath
  end

  def getChipDesign()
    return @chipDesign
  end

  def getSampleName()
    return @sampleName
  end

  def getLibraryName()
    return @libraryName
  end
  private 
  # Helper method to parse the flowcell definition file and extract values for
  # various fields needed for analysis.
  def parseFieldsFromXML(fcDefnXML, laneBarcode)
    xmlDoc = Hpricot::XML(open(fcDefnXML))

    fcName = xmlDoc.at("FCInfo")['Name']
    numCycles = xmlDoc.at("FCInfo")['NumCycles']
    @readLength = Integer(numCycles.slice(/\d+/)) - 1
    @fcType = xmlDoc.at("FCInfo")['Type']

    fcBarcodeMatched = false

    xmlDoc.search("FCInfo/LaneBarcodeInfo/LaneBarcode").each do |laneBC|
      if laneBC['ID'].eql?(laneBarcode.to_s)
        fcBarcodeMatched = true

        reference = laneBC['ReferencePath']
        if reference != nil && !reference.empty?()
          @refPath = reference.to_s
        end
        
        chipDesign = laneBC['ChipDesign']
        if chipDesign != nil && !chipDesign.empty?()
          @chipDesign = chipDesign.to_s
        end

        sample = laneBC['Sample']
        if sample != nil && !sample.empty?()
          @sampleName = sample.to_s
        end

        library = laneBC['Library']
        if library != nil && !library.empty?()
          @libraryName = library.to_s
        end
      end
    end

    if fcBarcodeMatched == false
      raise "Invalid barcode specified : " + laneBarcode.to_s
    end
  end
end
