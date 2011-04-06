#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "third_party")
$:.unshift File.dirname(__FILE__)

require 'PipelineHelper'

# Class to obtain information about a specific lane barcode from LIMS
# This information includes read length (number of cycles), paired / fragment,
# sample ID, library name, reference path and chip design.
class FCInfo
  def initialize(fc, laneBarcode)
    @limsScript  = "/stornext/snfs5/next-gen/Illumina/ipipe/third_party/getAnalysisPreData.pl"
    @pHelper     = PipelineHelper.new
    @fcName      = @pHelper.formatFlowcellNameForLIMS(fc)
    @laneBarcode = laneBarcode
    @libraryName = nil
    @refPath     = nil
    @numCycles   = 0
    @paired      = false
    @chipDesign  = nil
    @sample      = nil
    @pHelper     = PipelineHelper.new
    
    begin
      contactLIMS()
    rescue Exception => e
      puts e.message
    end
  end

  # Return library name for the corresponding 
  def getLibraryName()
    return @libraryName
  end

  # Method to obtain number of cycles per run
  def getNumCycles()
    return @numCycles
  end

  # Method to find if FC is paired or fragment
  # True - paired, false - fragment
  def paired?()
    return @paired
  end

  # Method to retrieve reference paths for a specified lane
  def getRefPath()
    return @refPath
  end

  # Method to retrieve chip design name for a specified lane barcode
  def getChipDesignName()
    return @chipDesign
  end

  # Method to retrieve sample name for a specified lane barcode
  def getSampleName()
    return @sample
  end

  private

  # Method to find out if reference path returned from LIMS is
  # valid for specified lane. Returns true if path is valid, false
  # otherwise
  # THIS IS OBSOLETE - CHANGE IT OR REMOVE IT
  def refPathValid?(lane)
    refPath = @referencePaths[lane.to_s]

    # If reference is null or empty, return false 
    if refPath == nil || refPath.eql?("")
      return false
    end

    # A reference path "sequence" implies building only sequence, and no
    # alignment. Hence it is a valid reference
    if refPath.downcase.eql?("sequence")
      return true
    end

    # A reference path is invalid if any of the following is true
    # 1) It does not exist, or is not a valid directory
    # 2) It does not end with string "/squash"
    # If all of above are false, reference path is valid
    if !File::exist?(refPath) || !File::directory?(refPath) ||
       !refPath.match(/\/squash$/)
      return false
    end
    return true
  end

  # Helper method to handle errors encountered in interacting with LIMS
  # such as error in connecting to LIMS
  def handleError(msg)
    # For right now, throw an exception
    raise "Error in obtaining information from LIMS. " +
          "Error from LIMS : " + msg
  end

  # Invoke the LIMS perl script and parse the output if LIMS could be contacted
  def contactLIMS()
    cmd = "perl " + @limsScript + " " + @fcName.to_s + "-" + @laneBarcode
    puts cmd
    output = `#{cmd}`
    puts output
    exitCode = $?

    if output.downcase.match(/error/)
      handleError(output)
    end

    tokens = output.split(";")

    tokens.each do |token|
      if token.match(/FLOWCELL_TYPE=/)
         findFCType(token)
      elsif token.match(/Library=/)
         parseLibraryName(token)
      elsif token.match(/Sample=/)
         parseSampleName(token)
      elsif token.match(/ChipDesign=/)
         parseChipDesignName(token)
      elsif token.match(/NUMBER_OF_CYCLES_READ1=/)
         findNumCycles(token)
      elsif token.match(/NUMBER_OF_CYCLES_READ2=/)
         findNumCycles(token)
      elsif token.match(/BUILD_PATH=/)
         parseReferencePath(token)
      end
    end
  end

  # Helper method to parse the LIMS output to find reference path
  def parseReferencePath(output)
    if(output.match(/BUILD_PATH=\s+[Ss]equence/) ||
       output.match(/BUILD_PATH=[Ss]equence/))
       @refPath = "sequence"

    elsif(output.match(/BUILD_PATH=\s+\/data/) ||
         output.match(/BUILD_PATH=\/data/))
         @refPath = output.slice(/\/data\/slx\/references\/\S+/)
        
         # Since reference paths starting with /data/slx/references represent
         # format of reference paths in alkek, change the prefix of these paths
         # to match the file-system structure in ardmore.
         @refPath.gsub!(/\/data\/slx\/references/,
         "/stornext/snfs5/next-gen/Illumina/genomes")

    elsif(output.match(/BUILD_PATH=\s+\/stornext/) ||
         output.match(/BUILD_PATH=\/stornext/))
         # If LIMS already has correct path corresponding to the file
         # system structure in ardmore, return that path without any
         # modifications.
         @refPath = output.slice(/\/stornext\/\S+/)
    end
  end

  # Get number of cycles for the flowcell
  def findNumCycles(output)
    value = 0
    temp = output.slice(/NUMBER_OF_CYCLES_READ[12]=\d+/)
    if temp != nil && !temp.eql?("")
      value = Integer(temp.split("=")[1]) - 1
    end

    if value > @numCycles
      @numCycles = value
    end 
  end

  # Determine if FC is paired-end or fragment
  def findFCType(output)
    if(output.match(/FLOWCELL_TYPE=p/))
       @paired = true
    else
      @paired = false
    end
  end

  # Get the library name from the output
  def parseLibraryName(output)
    # Find the library name
    if output.match(/Library=/)
      @libraryName = output.gsub(/Library=/, "")
      if @libraryName != nil && !@libraryName.empty?()
        @libraryName.strip!
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

__END__
#To Test this class, comment the previous __END__ statement
obj = FCInfo.new("70EMPAAXX", "5")
puts "Library name = " + obj.getLibraryName()
puts "Num cycles = " + obj.getNumCycles().to_s
puts "Paired end : " + obj.paired?().to_s
refPath = obj.getRefPath()

if refPath != nil && !refPath.empty?()
  puts "Ref path = " + obj.getRefPath()
else
  puts "Did not find reference path"
end

chipDesign = obj.getChipDesignName()
if chipDesign != nil
  puts "Chip Design = " + chipDesign.to_s
else
  puts "chip design is null"
end
sample = obj.getSampleName()

if sample != nil
  puts "Sample =" + sample.to_s
else
  puts "sample is null"
end
puts "DONE"
