#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'PipelineHelper'
require 'rexml/document'
require 'rexml/formatters/pretty'
include REXML
require 'LaneInfo'
require 'EmailHelper'

# Class to build flowcell definition. It writes an XML file
# containing all the information relevant to analyze a flowcell.
# It writes a list of all the barcodes used in the flowcell, number of cycles,
# and information about each lane barcode such as read length, reference path,
# chip design information etc.

# Author Nirav Shah niravs@bcm.edu

class FlowcellDefinitionBuilder
  def initialize(fcName, outputDirectory)
    @pHelper    = PipelineHelper.new()  # Instantiate PipelineHelper
    @fcName     = extractFCNameForLIMS(fcName)
    @outFile    = "FCDefinition.xml"

    @laneBarcodes    = Array.new  # Lane barcodes for the given flowcell
    @laneBarcodeInfo = Hash.new # Hash table of information per lane barcode
    @numCycles    = ""
    @fcType       = nil

    getLaneBarcodeDefn()
    getLaneBarcodeInfo()
    outputName  = outputDirectory + "/FCAnalysisDefinition.xml" 
    writeXMLOutput(outputName)
  end

  private

  # Helper method to write the flowcell information to an XML
  def writeXMLOutput(outputXMLFile)
    @xmlDoc = Document.new() 
    rootElem =  @xmlDoc.add_element("FCInfo", "Name" => @fcName, "NumCycles" => @numCycles.to_s, 
                        "Type" => @fcType.to_s)

    laneBarcodeListElem = rootElem.add_element("LaneBarcodeList") 
    @laneBarcodes.each do |laneBC|
      laneBarcodeListElem.add_element("LaneBarcode", "Name" => laneBC)
    end

    laneBarcodeInfoElem = rootElem.add_element("LaneBarcodeInfo")
    
    @laneBarcodeInfo.each do |barcode, attrs|
      laneBarcodeInfoElem.add_element("LaneBarcode", attrs)
    end
    writeXML()
  end

  # Get name of each lane / lane barcode used in the flowcell 
  def getLaneBarcodeDefn()
    limsScript = "/stornext/snfs5/next-gen/Illumina/ipipe/third_party/" +
                 "getFlowCellInfo.pl"

    limsQueryCmd = "perl " + limsScript + " " + @fcName.to_s

    output = runLimsCommand(limsQueryCmd)

    # LIMS did not report any errors, proceed to parse the barcodes
    lines = output.split("\n")
    lines.each do |line|
     if(line.match(/-[1-8]$/))
        laneBC = line.slice(/[1-8]$/)
        @laneBarcodes << laneBC.to_s
      elsif line.match(/-[1-8]-ID[01][0-9]$/)
        laneBC = line.slice(/[1-8]-ID[01][0-9]$/)
        @laneBarcodes << laneBC.to_s
      elsif line.match(/-[1-8]-IDMB\d$/)
        laneBC = line.slice(/[1-8]-IDMB\d$/)
        @laneBarcodes << laneBC.to_s
      elsif line.match(/-[1-8]-IDMB\d\d$/)
        laneBC = line.slice(/[1-8]-IDMB\d\d$/)
        @laneBarcodes << laneBC.to_s
      end
    end
  end

  # Obtain the data for each lane / lane barcode such as sample name, library,
  # reference path, chip design etc
  def getLaneBarcodeInfo()
    limsScript = "/stornext/snfs5/next-gen/Illumina/ipipe/third_party/" +
                 "getAnalysisPreData.pl"

    @laneBarcodes.each do |laneBC|
      limsQueryCmd = "perl " + limsScript + " " + @fcName.to_s + "-" + laneBC.to_s
      output = runLimsCommand(limsQueryCmd)
      laneInfo   = LaneInfo.new(output)
      numCycles  = laneInfo.getNumCycles()
      fcType     = laneInfo.getFlowcellType()
      refPath    = laneInfo.getReferencePath()
      chipDesign = laneInfo.getChipDesign()
      sample     = laneInfo.getSampleName()
      library    = laneInfo.getLibraryName()

      if numCycles == nil || numCycles.empty?()
        @numCycles = ""
      else
        @numCycles = numCycles.to_s
      end

      if @fcType == nil && fcType != nil
        @fcType = fcType
      end

      attrs = Hash.new
      attrs["ID"] = laneBC
      attrs["ReferencePath"] = refPath 

      if sample != nil && !sample.empty?()
        attrs["Sample"] = sample
      end
      if library != nil && !library.empty?()
        attrs["Library"] = library
      end
      if chipDesign != nil && !chipDesign.empty?()
        attrs["ChipDesign"] = chipDesign.to_s
      end

      @laneBarcodeInfo[laneBC] = attrs 
    end
  end

  # Execute the command to query LIMS
  def runLimsCommand(limsQueryCmd)
     output = `#{limsQueryCmd}`

     if output.downcase.match(/error/)
       handleError(output)
     else
       return output
     end
  end

   # Helper method to reduce full flowcell name to FC name used in LIMS
  def extractFCNameForLIMS(fc)
    return @pHelper.formatFlowcellNameForLIMS(fc)
  end

  # Write the XML file corresponding to the given flowcell
  def writeXML()
    formatter = Formatters::Pretty.new(2)
    formatter.compact = true
    outputXML = File.new(@outFile, "w")
    outputXML.puts formatter.write(@xmlDoc.root,"")
    outputXML.close()
  end

  # In case of errors, send out email and exit
  def handleError(errorMsg)
    errorMessage = "Error while obtaining information from LIMS for flowcell : " +
                   @fcName + " Error message : " + errorMsg.to_s
    obj       = EmailHelper.new
    emailFrom = "sol-pipe@bcm.edu"
    emailTo   = obj.getErrorRecepientEmailList()
    emailSubject = "LIMS error while getting info for flowcell : " + @fcName.to_s
    obj.sendEmail(emailFrom, emailTo, emailSubject, errorMessage)
    puts errorMessage.to_s
    exit -1
  end
end

flowcellName  = ARGV[0]
destDirectory = ARGV[1]

obj = FlowcellDefinitionBuilder.new(flowcellName, destDirectory)
