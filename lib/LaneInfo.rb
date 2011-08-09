#!/usr/bin/ruby

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

=begin 
  # Get number of cycles for the flowcell
  def parseNumCycles(output)
    value = 0
    temp = output.slice(/NUMBER_OF_CYCLES_READ[12]=\d+/)
    if temp != nil && !temp.eql?("")
      value = Integer(temp.split("=")[1])
    end

    if value > @numCycles
      @numCycles = value
    end 
  end
=end

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
