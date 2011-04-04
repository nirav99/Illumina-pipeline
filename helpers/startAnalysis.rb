#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'asshaul.rb'
require 'fileutils'

# Class to automatically start the flowcells. It runs as part of a crontab job.
# On detecting that a flowcell has copied, it starts qseq generation
# automatically.
class AnalysisStarter
  def initialize(baseDir)
    initializeMembers()

    # Attempt to obtain the lock, if another instance of this program is
    # running, this operation will fail. Print a suitable message and exit.
    if !@lock.try_to_lock
      puts "Another instance of this program is running. Exiting..."
      exit 0
    end
    buildInstrumentList(baseDir)

    @instrList.each do |instrName|
      puts "Checking for new flowcells for sequencer : " + instrName.to_s
      @instrDir = baseDir + "/" + instrName.to_s

      puts "Directory : " + @instrDir.to_s
#=begin
      buildAnalyzedFCList()
      findNewFlowcells()

      @newFC.each do |fcName|
        if fcReady?(fcName) == true
          updateDoneList(fcName)
          processFlowcell(fcName)
        end
      end
#=end

    # Release the lock to allow another instance of this program to run.
    @lock.unlock
    end
  end

private
  def initializeMembers()
    @instrDir  = ""                   # Directory of instrument
    @instrList = ""                   # List of instruments
    @fcList    = nil                  # Flowcell list
    @completedFCLog = "done_list.txt" # List of flowcells analyzed
    @newFC     = Array.new            # Flowcell to analyze

    # Command to start a flowcell
    @startCmd  = "/stornext/snfs5/next-gen/software/bin/ruby QseqGenerator.rb"

    # Create a new lock - this acts like a Singleton pattern for this program.
    # The lock is a file "lock_$filename" in the directory where this code
    # lives.  It is used to prevent multiple instance of this program from
    # running at the same time.
    @lock      = Locker.new(File.dirname(__FILE__) + "/lock_startAnalysis.lock")
  end

  # Method to build a list of instruments
  def buildInstrumentList(baseDir)
    entries = Dir[baseDir + "/*"] 

    @instrList = Array.new

    entries.each do |entry|
      if !entry.eql?(".") && !entry.eql?("..") &&
         File::directory?(entry)

         @instrList << entry.slice(/[a-zA-Z0-9]+$/).to_s
      end
    end
  end

  # Build a hashtable of flowcells for which analysis was already started
  def buildAnalyzedFCList()
    logFile = @instrDir + "/" + @completedFCLog
    puts logFile
    lines = IO.readlines(logFile)

    @fcList = nil
    @fcList = Hash.new()
 
    if lines != nil && lines.length > 0
      lines.each do |line|
        @fcList[line.strip] = "1"
      end 
    end
  end

  # Find flowcells for which analysis is not yet started. Read the directory
  # listing under the instrument directory, compare directories against the list
  # of completed flowcells and find the directories (flowcells) that are new.
  def findNewFlowcells()
    @newFC = Array.new

    dirList = Dir.entries(@instrDir)

    dirList.each do |dirEntry|
      if !dirEntry.eql?(".") && !dirEntry.eql?("..") &&
         File::directory?(@instrDir + "/" + dirEntry) &&
         !@fcList.key?(dirEntry.strip)
         @newFC << dirEntry
      end
    end      
  end

  # Is flowcell ready to start the analysis ?, if yes return true else false
  # Current setup is that when a flowcell has copied over completely, the owner
  # of that flowcell is changed from nobody to p-illumina. Thus, if we find
  # p-illumina in long directory listing of that FC, it is ready to begin
  # analysis.
  # TODO: THIS MUST BE IMPROVED WHEN MORE INFORMATION IS AVAILABLE.
  def fcReady?(fcName)
    cmd = "ls -ld " + @instrDir + "/" + fcName

#    output = `#{cmd}`

#    if output.match(/p-illumina/) && File::owned?(@instrDir + "/" + fcName)
    if File::owned?(@instrDir + "/" + fcName)
      puts "Flowcell " + fcName + " is ready for analysis"
      return true
    else
      return false
    end
  end

  # Add the entry of the flowcell to "done" list so that it won't be processed
  # more than once.
  def updateDoneList(fcName)
    logFileName = @instrDir + "/" + @completedFCLog
    logFile = File.new(logFileName, "a")
    puts "Adding to log : " + logFileName + " FC : " + fcName.to_s
    logFile.puts fcName
    logFile.close 
  end

  # Start the analysis for the flowcell. For now, simply generate and split Qseq
  # files.
  # TODO: Needs to be improved when reference paths are correctly available from
  # LIMS.
  def processFlowcell(fcName)
    puts "Starting analysis for flowcell : " + fcName.to_s
    currDir = Dir.pwd
    Dir::chdir("/stornext/snfs5/next-gen/Illumina/ipipe/lib")
    cmd = "ruby QseqGenerator.rb " + fcName.to_s
    puts "Running command : " + cmd.to_s
#=begin
    output = `#{cmd}`
    puts output
#=end
    Dir::chdir(currDir)
  end
end

obj = AnalysisStarter.new("/stornext/snfs0/next-gen/Illumina/Instruments")
