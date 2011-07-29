#!/usr/bin/ruby

# Class to obtain the run finished date for a given list of flowcells
# Author Nirav Shah niravs@bcm.edu
class RunFinishedDateRetriever
  # The input MUST be machine_name flowcell_name pairs separated by spaces
  def initialize(inputParams)
    # Array of parent directories where to search for a flowcell
    @instrumentDir = Array.new
    @instrumentDir << "/stornext/snfs0/next-gen/Illumina/Instruments/"

    @seqNames     = Array.new    # Names of sequencers
    @fcNames      = Array.new    # Names of flowcells
    @finishedDate = Array.new    # Run finished dates for a given flowcell on
                                 # given machine

    idx = 0

    # Split the input into machine names and flowcell names. The input expected
    # is machinename flowcell machinename flowcell ...
    while idx < inputParams.length
      if idx % 2 == 0
        @seqNames << inputParams[idx]
      else
        @fcNames << inputParams[idx]
      end
      idx += 1
    end

    idx = 0

    # Build the array of finished dates, or appropriate error texts.
    while idx < @seqNames.length
      @finishedDate << findRunFinishedDate(@seqNames[idx], @fcNames[idx])
      idx += 1
    end

    idx = 0

    # Print the lists - might want to do something different eventually
    while idx < @seqNames.length
      puts @seqNames[idx] + ";" + @fcNames[idx] + ";" + @finishedDate[idx]
      idx += 1
    end
  end

  private
  # Given a machine name and a flowcell name, return the run finished date or
  # appropriate error message. As of 22nd July 2011, a run is considered
  # complete when a file "RTAComplete.txt" is written to the flowcell directory.
  # If this file is found, return the creation date of this file as the run
  # finished date. 
  # If the flowcell has not finished sequencing, or RTA has not finished copying
  # the data, this file will be absent. In this case, return "none" to indicate
  # that run finished information is not available now.
  # If the flowcell path was bad, either flowcell name was incorrect, or machine
  # name was incorrect, then return INVALID_FLOWCELL to let the caller know that
  # the flowcell information was bad.
  def findRunFinishedDate(seqName, fcName)
    foundFCDir           = false
    foundRunFinishedDate = false

    @instrumentDir.each do |instDir|
      searchPath = instDir + seqName

      if File::directory?(searchPath)
        fcPaths     = getFlowcellDirectoryNames(searchPath, fcName)

        fcPaths.each do |fcPath|
          if File::directory?(fcPath)
             runFinishedMarkerFile = fcPath + "/RTAComplete.txt"
             foundFCDir = true
             if File::exist?(runFinishedMarkerFile)
               creationTime = File::ctime(runFinishedMarkerFile).strftime("%Y-%m-%d")
               foundRunFinishedDate = true
               return creationTime.to_s
             end
          end
        end
      end
    end
    
    if foundFCDir == false
      return "INVALID_FLOWCELL"
    elsif foundRunFinishedDate == false
      return "NONE"
    end
  end

  # Given a directory search path and a flowcell name, get all directory paths
  # matching the flowcell name (especially when incomplete name is used).
  # This method can handle complete flowcell directory names as well as the
  #  flowcell names used in LIMS.
  def getFlowcellDirectoryNames(searchPath, fcName)
    result     = Array.new
    dirEntries = Dir.entries(searchPath)

    dirEntries.each do |dirEntry|
      if dirEntry.match(fcName)
        result << searchPath + "/" + dirEntry
      end
    end
    return result
  end
end

inputParams = ARGV
obj = RunFinishedDateRetriever.new(inputParams)
