#!/usr/bin/env ruby
# This script automates data copy operations from solexa-dump-1
# to the corresponding slxarchivework_{x} volume

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'asshaul.rb'
require 'fileutils'

class SlxDataCopier
  def initialize(sequencerName)
    @seqName = sequencerName

    # Obtain source paths
    @srcPath    = "/slxdump2/incoming/"
    @remoteUser = "sol-pipe@172.30.18.12"

    # Obtain destination path slxarchivework_{x} 
    if @seqName.to_s.match(/376/)
      @destPath = "/data/slx/slxarchivework_10/"
    elsif @seqName.to_s.match(/034/)
      @destPath = "/data/slx/slxarchivework_9/"
    else
      raise "Invalid sequencer name specified"
    end

    puts @destPath

    # Enable logging
    @logDir  = @destPath + ".incoming.queue/logs/"
    @logFile = @logDir + "EAS" + @seqName.to_s + ".log"
    SingleLogger.instance.set_output(@logFile)

    # Create a lock - to prevent another instance of this program
    # for the same sequencer to run
    @lock    = Locker.new(@logDir + "lock__" + @seqName.to_s)

    # List of new and done flowcells - these are not used right now
    @doneFC   = StoreItems.new(@logDir + "done_items_EAS" + @seqName)
    @newFC    = StoreItems.new(@logDir + "new_items_EAS" + @seqName)

    findFlowCellToCopy()
  end

  private

  def findFlowCellToCopy()
    logInfo("Starting data copy operation for sequencer : " + @seqName) 
    if !@lock.try_to_lock
      logInfo("Another instance of this program is running. Exiting...")
      exit 0
    end

    output = `ssh #{@remoteUser} ls #{@srcPath}`
    listFiles = output.split("\n")

    listFiles.each do |item|
      if isFlowcell(item)
        logInfo("Found : " + item)
        #TODO: THIS PART NEEDS TO BE CORRECTED/IMPROVED
        if !allCopied?(item)
          logInfo("Copying data for flowcell : " + item)
          copyData(item)
        else
          if sequencingDone?(item)
            logInfo("Data copied and sequencing done : " + item)
            logInfo("Looks like this FC finished copying")
          else
            logInfo("Data copied for now for FC : " + item)
            logInfo("Will check again on next iteration")
          end
        end
       # if !sequencingDone?(item) || !allCopied?(item)
       #   logInfo("Copying data for flowcell : " + item)
       #   copyData(item)
       # end
      end
    end
    @lock.unlock
  end

  # Method to run the actual rsync command
  def copyData(fcName)
    FileUtils.mkdir_p(@destPath + "/" + fcName + "/Data")
    rsyncCmd = "rsync -az -e ssh " + @remoteUser + ":" + @srcPath +
               fcName + "/Data/ " + @destPath + fcName + "/Data"
    logInfo(rsyncCmd)
    `#{rsyncCmd}`
    logInfo("rsync completed")
  end

  # Helper method to validate that given directory is a flowcell
  def isFlowcell(dirName)
    # Specified directory is a flowcell if it satisfies
    # the format 100123_USI-EAS034_ ,i.e., 6 digits followed
    # by "_" then "USI-EAS", seqName and "_"
    if dirName.match(/^\d{6}_USI-EAS#{@seqName}_/)
      return true
    else
      return false
    end
  end
 
  # Method to identify if sequencing is done for specified flowcell
  def sequencingDone?(fcName)
    # If sequencing is completed, a file Run.completed will be present in FC
    # directory on the source
    `ssh #{@remoteUser} ls #{@srcPath}/#{fcName}/Run.completed 2>/dev/null`.split("\n").size == 1
  end

  # Method to determine if all data is copied
  def allCopied?(fcName)
    dryRunCmd = "rsync -avz --dry-run -e ssh " + @remoteUser + ":" +
                @srcPath + fcName + "/Data/ " + @destPath + fcName + "/Data"
    output = `#{dryRunCmd}`            
    lines  = output.split("\n")

    logInfo("dry run line size = " + lines.size.to_s)

    # If all data is copied over, dry-run will show empty 2nd line, i.e.,
    # names of files remaining to be copied. Moreover, the size of this
    # array would be either 4 or 5, hence I specified <= 5
    return lines[1] == "" && lines.size <= 5
  end

  # Helper method to log the information messages to log file
  def logInfo(message)
    SingleLogger.instance.info message
    puts message
  end
end

obj = SlxDataCopier.new(ARGV[0])
