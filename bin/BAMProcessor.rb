#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'EmailHelper'
require 'EnvironmentInfo.rb'

# Class to apply various Picard/Custom tools to generate a BAM file and
# calculate alignment stats.
# Author Nirav Shah niravs@bcm.edu

class BAMProcessor
  # Constructor 
  # isPairedEnd   - true if flowcell is paired end, false otherwise
  # phixFilter    - true if phix reads should be filtered, false otherwise
  # samFileName   - Name of the sam file
  # sortedBAMName - Name of the bam that is coordinate sorted
  # finalBAMName  - Name of the final BAM file
  def initialize(isPairedEnd, phixFilter, samFileName, sortedBAMName,
                 finalBAMName)

    @samFileName = samFileName
    @sortedBam   = sortedBAMName
    @markedBam   = finalBAMName

    # Is SAM/BAM fragment or paired end
    @isFragment = !isPairedEnd

    # Whether to filter out phix reads or not
    @filterPhix = phixFilter

    # Directory hosting various custom-built jars
    @javaDir         = "/stornext/snfs5/next-gen/Illumina/ipipe/java"

    # Parameters for picard commands
    @picardPath       = "/stornext/snfs5/next-gen/software/picard-tools/current"
    @picardValStr     = "VALIDATION_STRINGENCY=LENIENT"
    # Name of temp directory used by picard
    @picardTempDir   = "TMP_DIR=/space1/tmp"
    # Number of records to hold in RAM
    @maxRecordsInRam = 3000000
    # Maximum Java heap size
    @heapSize        = "-Xmx22G"

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
          " MAX_RECORDS_IN_RAM=" + @maxRecordsInRam.to_s + " " + @picardValStr +
          " 1>sortbam.o 2>sortbam.e"
    return cmd
  end

  # Mark duplicates on a sorted BAM
  def markDupCommand()
    cmd = "java " + @heapSize + " -jar " + @picardPath + "/MarkDuplicates.jar I=" +
          @sortedBam + " O=" + @markedBam + " " + @picardTempDir + " " +
          "MAX_RECORDS_IN_RAM=" + @maxRecordsInRam.to_s + " AS=true M=metrics.foo " +
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
           @samFileName.to_s + " O=" + @sortedBam + " SO=coordinate " + @picardTempDir + " MAX_RECORDS_IN_RAM=" + 
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
          " O=BWA_Map_Stats.txt 1>mappingStats.o 2>mappingStats.e" 
    return cmd
  end

  # Method to handle error. Current behavior, print the error stage and abort.
  def handleError(commandName)
    errorMessage = "Error while processing command : " + commandName.to_s
    # For now keep like this
    emailText    = errorMessage.to_s

    obj          = EmailHelper.new()
    emailFrom    = "sol-pipe@bcm.edu"
    emailTo      = obj.getErrorRecepientEmailList()
    emailSubject = "Error during mapping on host " + @envInfo.getHostName() 

    obj.sendEmail(emailFrom, emailTo, emailSubject, emailText)

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

fcPairedEnd     = ARGV[0]
filterPhixReads = ARGV[1]
samFileName     = ARGV[2]
sortedBAMName   = ARGV[3]
finalBAMName    = ARGV[4]

obj = BAMProcessor.new(fcPairedEnd, filterPhixReads, samFileName, sortedBAMName,
                       finalBAMName)
obj.process()
