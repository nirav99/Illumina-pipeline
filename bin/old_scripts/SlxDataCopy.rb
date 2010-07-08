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

    # Obtain destination path
    if @seqName.to_s.match(/376/)
      @destPath = "/stornext/snfs5/next-gen/Illumina/Instruments/EAS376/"
    elsif @seqName.to_s.match(/034/)
      @destPath = "/stornext/snfs5/next-gen/Illumina/Instruments/EAS034/"
    elsif @seqName.to_s.match(/142/)
      @destPath = "/stornext/snfs5/next-gen/Illumina/Instruments/700142/"
    elsif @seqName.to_s.match(/166/)
      @destPath = "/stornext/snfs5/next-gen/Illumina/Instruments/700166/"
    else
      raise "Invalid sequencer name specified"
    end

    puts @destPath

    # Enable logging
    @logDir  = @destPath + ".incoming.queue/logs/"
    @logFile = @logDir + "SEQ" + @seqName.to_s + ".log"
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

        if @doneFC.exists?(item)
          logInfo("Flowcell " + item + " finished copying. Ignoring ...")
        else

          #TODO: THIS PART NEEDS TO BE CORRECTED/IMPROVED
          if !allCopied?(item)
            logInfo("Copying data for flowcell : " + item)
            copyData(item)
          else
            if sequencingDone?(item) && rtaResultsCopied?(item)
              logInfo("Data copied and sequencing done : " + item)
              logInfo("Looks like this FC finished copying")
              if !@doneFC.exists?(item)
                @doneFC.add(item)
              end
            else
              logInfo("Data copied for now for FC : " + item)
              logInfo("Will check again on next iteration")
            end
          end
        end
      end
    end
    @lock.unlock
  end

  # Method to run the actual rsync command
  def copyData(fcName)
    begin
      FileUtils.mkdir_p(@destPath + "/" + fcName + "/Data")
      rsyncCmd = "rsync -az -e ssh " + @remoteUser + ":" + @srcPath +
                 fcName + "/Data/ " + @destPath + fcName + "/Data"
      logInfo(rsyncCmd)
      `#{rsyncCmd}`
      logInfo("rsync completed")
    rescue Exception => e
      logInfo("Encountered exception in copyData function")
      logInfo(e.message)
      logInfo(e.backtrace.inspect)

      # On encountering an exception, delete lock file
      # and exit
      @lock.unlock
      exit -1
    end
  end

  # Helper method to validate that given directory is a flowcell
  def isFlowcell(dirName)
    # Specified directory is a flowcell if it satisfies
    # the format 100123_USI-EAS034_ ,i.e., 6 digits followed
    # by "_" then "USI-EAS", seqName and "_"
    #TODO: change this regex when correct FC name from HiSeq is determined
    if dirName.match(/^\d{6}_USI-EAS#{@seqName}_/) ||
       dirName.match(/HSQ/)
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

  # Method to identify if RTA results are copied for specified flowcell
  def rtaResultsCopied?(fcName)
    # File copied to FC directory when RTA results for fragment run are copied
    trigFileFragment     = "Basecalling_Netcopy_complete_SINGLEREAD.txt"

    # File copied to FC directory when RTA results for paired run are copied
    trigFileRead1        = "Basecalling_Netcopy_complete_READ1.txt"
    trigFileRead2        = "Basecalling_Netcopy_complete_READ2.txt"

    # File copied to FC directory when RTA results for either read are copied
    trigFileBaseCopyDone = "Basecalling_Netcopy_complete.txt"

    baseCmd = "ssh " + @remoteUser + " ls " + @srcPath + "/" + fcName

    # Check if file Basecalling_Netcopy_complete.txt is present
    foundNetCopy = `#{baseCmd}/#{trigFileBaseCopyDone} 2>/dev/null`.split("\n").size == 1

    # Check if base calls results are copied for fragment run
    fragBCCopied = `#{baseCmd}/#{trigFileFragment} 2>/dev/null`.split("\n").size == 1

    if foundNetCopy && fragBCCopied
      return true
    end

    # Check if base calls results are copied for read 1 of paired run
    read1BCCopied = `#{baseCmd}/#{trigFileRead1} 2>/dev/null`.split("\n").size == 1 

    # Check if base calls results are copied for read 1 of paired run
    read2BCCopied = `#{baseCmd}/#{trigFileRead2} 2>/dev/null`.split("\n").size == 1 

    if foundNetCopy && read1BCCopied && read2BCCopied
      return true
    else
      return false
    end
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
