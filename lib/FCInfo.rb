#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "third_party")

#Class to obtain flowcell information from LIMS
class FCInfo
  def initialize(fc, laneBarcode)
    @limsScript  = "/stornext/snfs5/next-gen/Illumina/ipipe/third_party/getAnalysisPreData.pl"
    @fcName      = extractFC(fc)
    @laneBarcode = laneBarcode
    @libraryName = ""
    @refPath     = ""
    @numCycles   = 0
    @paired      = false
    @chipDesign  = nil
    
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

  # Helper method to reduce full flowcell name to FC name used in LIMS
  def extractFC(fc)
    flowCellName = nil
    temp = fc.slice(/FC(.+)$/)
    if temp == nil
      flowCellName = fc.slice(/([a-zA-Z0-9]+)$/)
    else
      flowCellName = temp.slice(2, temp.size)
    end
    # With HiSeqs, a flowcell would have a prefix letter "A" or "B". 
    # We remove that letter from the flowcell name since the flowcell
    # is not entered with that prefix in LIMS.
    # For GA2, this does not have any effect.
    flowCellName.slice!(/^[a-zA-Z]/)
    return flowCellName
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

    # If information was successfully obtained from LIMS, parse the output
    findFCType(output)
    findNumCycles(output)
    parseReferencePath(output)
    parseLibraryName(output)
    parseChipDesignName(output)
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
    temp = output.slice(/NUMBER_OF_CYCLES_READ1=\d+/)
    if temp != nil && !temp.eql?("")
      @numCycles = Integer(temp.split("=")[1]) - 1
    else
      @numCycles = 0
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
      @libraryName = output.slice(/Library=\S+/) 
      @libraryName.gsub!(/Library=/, "")
    end
  end

  # Get the chip design name from the output
  def parseChipDesignName(output)
    if output.match(/ChipDesign=\S+/)
      temp = output.slice(/ChipDesign=\S+/)
      temp.gsub!(/ChipDesign=/, "")
      if !temp.match(/^[Nn]one/)
        @chipDesign = temp.to_s
      end
    end
  end
end

__END__
#To Test this class, comment the previous __END__ statement
obj = FCInfo.new("110107_SN601_0070_A818TJABXX1", "8")
puts obj.getLibraryName()
puts obj.getNumCycles()
puts obj.paired?().to_s
puts obj.getRefPath()
puts obj.getChipDesignName()
puts "DONE"
