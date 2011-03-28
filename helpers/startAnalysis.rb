#!/usr/bin/ruby

class AnalysisStarter
  def initialize(iDir)
    initializeMembers()
    @instrDir = iDir    
    buildAnalyzedFCList()
    findNewFlowcells()

    @newFC.each do |fcName|
      if fcReady?(fcName) == true
        updateDoneList(fcName)
        processFlowcell(fcName)
      end
    end
  end

private
  def initializeMembers()
    @instrDir = ""                    # Directory of instrument
    @fcList   = nil                   # Flowcell list
    @completedFCLog = "done_list.txt" # List of flowcells analyzed
    @newFC    = Array.new             # Flowcell to analyze
  end

  # Build a hashtable of flowcells for which analysis was already started
  def buildAnalyzedFCList()
    logFile = @instrDir + "/" + @completedFCLog
    lines = IO.readlines(logFile)

    @fcList = Hash.new()
 
    lines.each do |line|
      @fcList[line] = "1"
    end 

    puts "Completed FC List : "
    puts @fcList.keys
  end

  # Find flowcells for which analysis is not yet started. Read the directory
  # listing under the instrument directory, compare directories against the list
  # of completed flowcells and find the directories (flowcells) that are new.
  def findNewFlowcells()
    dirList = Dir.entries(@instrDir)

    dirList.each do |dirEntry|
      if !dirEntry.eql?(".") && !dirEntry.eql?("..") &&
         File::directory?(@instrDir + "/" + dirEntry) &&
         !@fcList.key?(dirEntry)
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

    output = `#{cmd}`

    if output.match(/p-illumina/ && File::owned?(@instrDir + "/" + fcName))
      puts "Flowcell " + fcName + " is ready for analysis"
      return true
    else
      return false
    end
  end

  # Add the entry of the flowcell to "done" list so that it won't be processed
  # more than once.
  def updateDoneList(fcName)
    logFile = File.new(@instrDir + "/" + @completedFCLog, "a")
    logFile.puts fcName
    logFile.close 
  end

  # Start the analysis for the flowcell. For now, simply generate and split Qseq
  # files.
  # TODO: Needs to be improved when reference paths are correctly available from
  # LIMS.
  def processFlowcell(fcName)
    currDir = Dir.pwd
    Dir::chdir("/stornext/snfs5/next-gen/Illumina/ipipe/lib")
    cmd = "ruby QseqGenerator.rb " + fcName.to_s
    output = `#{cmd}`
    puts output
    Dir::chdir(currDir)
  end
end

obj = AnalysisStarter.new("/stornext/snfs0/next-gen/Illumina/Instruments/700166")
