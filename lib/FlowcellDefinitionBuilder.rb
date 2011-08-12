#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'PipelineHelper'
require 'rexml/document'
require 'rexml/formatters/pretty'
include REXML
#require 'LaneInfo'
require 'EmailHelper'

# Class to parse LIMS output to obtain information for specified lane barcode
# Author Nirav Shah niravs@bcm.edu
class LaneInfo
  def initialize(limsOutput)
    @refPath        = nil       # Reference path
    @sample         = nil       # Sample name
    @library        = nil       # Library name
    @chipDesign     = nil       # Chip design
    @fcType         = "paired"  # Whether fragment or paired
    @numCycles      = ""        # Num. cycles for read 1 or read 2
    parseLIMSOutput(limsOutput)
  end

  # Get methods for various flowcell lane barcode properties
  def getNumCycles()
    return @numCycles.to_s
  end

  def getFlowcellType()
    return @fcType.to_s
  end

  def getReferencePath()
    return @refPath
  end

  def getChipDesign()
    return @chipDesign
  end

  def getLibraryName()
    return @library.to_s
  end

  def getSampleName()
    return @sample.to_s
  end
  
  private
  # Parse the output from LIMS
  def parseLIMSOutput(limsOutput)
    tokens = limsOutput.split(";")

    tokens.each do |token|
      if token.match(/FLOWCELL_TYPE=/)
         parseFCType(token)
      elsif token.match(/Library=/)
         parseLibraryName(token)
      elsif token.match(/Sample=/)
         parseSampleName(token)
      elsif token.match(/ChipDesign=/)
         parseChipDesignName(token)
      elsif token.match(/NUMBER_OF_CYCLES_READ1=/)
         parseNumCycles(token)
      elsif token.match(/NUMBER_OF_CYCLES_READ2=/)
         parseNumCycles(token)
      elsif token.match(/BUILD_PATH=/)
         parseReferencePath(token)
      end
    end    
  end

  # Determine if FC is paired-end or fragment
  def parseFCType(output)
    if(output.match(/FLOWCELL_TYPE=p/))
      @fcType = "paired"
    else
      @fcType = "fragment"
    end
  end

  # Extract reference path
  def parseReferencePath(output)
    if(output.match(/BUILD_PATH=\s+[Ss]equence/) ||
       output.match(/BUILD_PATH=[Ss]equence/))
       @refPath = "sequence"
    elsif(output.match(/BUILD_PATH=\s+\/stornext/) ||
       output.match(/BUILD_PATH=\/stornext/))
       @refPath = output.slice(/\/stornext\/\S+/)
    end
  end

  # Get the library name from the output
  def parseLibraryName(output)
    if output.match(/Library=/)
      @library = output.gsub(/Library=/, "")
      if @library != nil && !@library.empty?()
        @library.strip!
      end
    end
  end

  # Get the chip design name from the output
  def parseChipDesignName(output)
    if output.match(/ChipDesign=/)
      temp = output.gsub(/ChipDesign=/, "")
      temp.strip!
      if !temp.match(/^[Nn]one/)
        @chipDesign = temp.to_s
      end
    end
  end

  # Get the number of cycles for the flowcell. If the flowcell has barcodes,
  # the number of cycles would be something like 101+7, leave it the way it is.
  # The parser program should convert it to an integer value.
  def parseNumCycles(output)
     temp = output.slice(/NUMBER_OF_CYCLES_READ[12]=[^;]+/)
     temp.gsub!(/NUMBER_OF_CYCLES_READ[12]=/, "")
     @numCycles = temp
  end

  # Get the sample name from the output
  def parseSampleName(output)
    if output.match(/Sample=\S+/)
      temp = output.gsub(/Sample=/,"")
      temp.strip!
      if !temp.match(/^[Nn]one/)
        @sample = temp.to_s
      else
        @sample = nil
      end
    end
  end
end



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
      line.gsub!(/^[A-Za-z0-9_]+-/, "")
      @laneBarcodes << line.to_s
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
