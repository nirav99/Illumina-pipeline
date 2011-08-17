#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'EmailHelper'
require 'EnvironmentInfo.rb'
require 'yaml'

# Class to apply various Picard/Custom tools to generate a BAM file and
# calculate alignment stats.
# Author Nirav Shah niravs@bcm.edu

class BAMProcessor
  # Constructor 
  # fcBarcode     - LIMS barcode for the flowcell
  # isPairedEnd   - true if flowcell is paired end, false otherwise
  # phixFilter    - true if phix reads should be filtered, false otherwise
  # samFileName   - Name of the sam file
  # sortedBAMName - Name of the bam that is coordinate sorted
  # finalBAMName  - Name of the final BAM file
  def initialize(fcBarcode, isPairedEnd, phixFilter, samFileName, sortedBAMName,
                 finalBAMName)
    @fcBarcode   = fcBarcode
    @samFileName = samFileName
    @sortedBam   = sortedBAMName
    @markedBam   = finalBAMName

    # Is SAM/BAM fragment or paired end
    @isFragment = !isPairedEnd

    # Whether to filter out phix reads or not
    @filterPhix = phixFilter

    # Directory hosting various custom-built jars
    @javaDir         = File.dirname(File.dirname(__FILE__)) + "/java"

    # Read picard parameters from yaml config file
    yamlConfigFile = File.dirname(File.dirname(__FILE__)) + "/config/config_params.yml"
    @configReader =  YAML.load_file(yamlConfigFile)

    # Parameters for picard commands
    @picardPath       = @configReader["picard"]["path"]
    puts "Picard path = " + @picardPath
    @picardValStr     = @configReader["picard"]["stringency"]
    puts "Picard validation stringency = " + @picardValStr
    @picardTempDir    = @configReader["picard"]["tempDir"]
    puts "Picard temp dir = " + @picardTempDir
    @maxRecordsInRam  = @configReader["picard"]["maxRecordsInRAM"]
    puts "Max records in ram = " + @maxRecordsInRam.to_s
    @heapSize         = @configReader["picard"]["maxHeapSize"]
    puts "Heap Size = " + @heapSize.to_s

    @envInfo = EnvironmentInfo.new()
  end

  # Apply the series of command to generate a final BAM
  def process()
    puts "Displaying environment characteristics"
    @envInfo.displayEnvironmentInformation(true)
   
    if @isFragment == false
       puts "Fixing Mate information"
       cmd = fixMateInfoCmd()
       runCommand(cmd, "fixMateInformation") 
    else
       puts "Fragment run, sorting BAM"
       cmd = sortBamCommand()
       runCommand(cmd, "sortBam")
    end

    puts "Marking Duplicates"
    cmd = markDupCommand()
    runCommand(cmd, "markDups")

    if @filterPhix == true
       puts "Filtering out phix reads"
       cmd = filterPhixReadsCmd(@markedBam)
       runCommand(cmd, "filterPhix")
    end    

   puts "Fixing CIGAR for unmapped reads"
   cmd = fixCIGARCmd(@markedBam) 
   runCommand(cmd, "fixCIGAR")

   puts "Calculating mapping stats"
   cmd = mappingStatsCmd()
   runCommand(cmd, "mappingStats")
  end 

  private
  # Sort the BAM by mapping coordinates
  def sortBamCommand()
    cmd = "java " + @heapSize + " -jar " + @picardPath + "/SortSam.jar I=" + @samFileName +
          " O=" + @sortedBam + " SO=coordinate " + @picardTempDir + " " +
          @maxRecordsInRam.to_s + " " + @picardValStr + " 1>sortbam.o 2>sortbam.e"
    return cmd
  end

  # Mark duplicates on a sorted BAM
  def markDupCommand()
    cmd = "java " + @heapSize + " -jar " + @picardPath + "/MarkDuplicates.jar I=" +
          @sortedBam + " O=" + @markedBam + " " + @picardTempDir + " " +
          @maxRecordsInRam.to_s + " AS=true M=metrics.foo " +
          @picardValStr  + " 1>markDups.o 2>markDups.e"
    return cmd
  end

  # Filter reads mapping to phix and phix contig from the BAM header
  def filterPhixReadsCmd(bamFile)
    jarName = @javaDir + "/PhixFilterFromBAM.jar"
    cmd = "java " + @heapSize + " -jar " + jarName + " I=" + bamFile + 
          " 1>phixFilter.o 2>phixFilter.e"
    return cmd
  end
 
  # Correct the flag describing the strand of the mate
  def fixMateInfoCmd()
    cmd = "java " + @heapSize + " -jar " + @picardPath + "/FixMateInformation.jar I=" +
           @samFileName.to_s + " O=" + @sortedBam + " SO=coordinate " + @picardTempDir + " " + 
           @maxRecordsInRam.to_s + " " + @picardValStr + " 1>fixMateInfo.o 2>fixMateInfo.e"
    return cmd
  end

  # Correct the unmapped reads. Reset CIGAR to * and mapping quality to zero.
  def fixCIGARCmd(bamFile)
    jarName = @javaDir + "/FixCIGAR.jar"
    cmd = "java " + @heapSize + " -jar " + jarName + " I=" + bamFile +
          " 1>fixCIGAR.o 2>fixCIGAR.e"
    return cmd
  end

  # Method to build command to calculate mapping stats
  def mappingStatsCmd()
    jarName = @javaDir + "/BAMAnalyzer.jar"
    cmd = "java " + @heapSize + " -jar " + jarName + " I=" + @markedBam +
          " O=BWA_Map_Stats.txt X=BAMAnalysisInfo.xml 1>mappingStats.o 2>mappingStats.e" 
    return cmd
  end

  # Method to handle error. Current behavior, print the error stage and abort.
  def handleError(commandName)
    errorMessage = "Error while processing command : " + commandName.to_s +
                   " for flowcell : " + @fcBarcode.to_s + " Working Dir : " +
                   Dir.pwd.to_s + " Hostname : " +  @envInfo.getHostName() 
    # For now keep like this
    emailSubject = "Error while mapping : " + @fcBarcode.to_s

    obj          = EmailHelper.new()
    emailFrom    = "sol-pipe@bcm.edu"
    emailTo      = obj.getErrorRecepientEmailList()
    emailSubject = "Error during mapping on host " + @envInfo.getHostName() 

    obj.sendEmail(emailFrom, emailTo, emailSubject, errorMessage)

    puts errorMessage.to_s
    exit -1
  end

  # Method to run the specified command
  def runCommand(cmd, cmdName)
    startTime = Time.now
    `#{cmd}`
    endTime   = Time.now
    returnValue = $?
    displayExecutionTime(startTime, endTime)

    if returnValue != 0
      handleError(cmdName)
    end
  end

  # Display execution time as the difference between start time and end time
  def displayExecutionTime(startTime, endTime)
    timeDiff = (endTime - startTime) / 3600
    puts "Execution time : " + timeDiff.to_s + " hours"
  end

  @isFragment    = false # Is read fragment, default is paired (true)
  @samFileName   = nil   # Name of SAM file to generate using BWA
  @sortedBam     = nil   # Name of sorted BAM
  @markedBam     = nil   # Name of BAM with duplicates marked
  @picardPath    = nil   # Picard path
end 

fcBarcode       = ARGV[0]
fcPairedEnd     = ARGV[1]
filterPhixReads = ARGV[2]
samFileName     = ARGV[3]
sortedBAMName   = ARGV[4]
finalBAMName    = ARGV[5]

obj = BAMProcessor.new(fcBarcode, fcPairedEnd, filterPhixReads, samFileName, 
                       sortedBAMName, finalBAMName)
obj.process()
