#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

#require 'PipelineHelper'

# Class to apply various Picard/Custom tools to generate a BAM file and
# calculate alignment stats.
# Author Nirav Shah niravs@bcm.edu

class BAMProcessor
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
  end

  def process()
    puts "Obtaining node characteristics"
    displayNodeCharacteristics()
    
    # Command to sort a SAM file into a BAM
    puts "Sorting BAM"
    cmd = sortBamCommand()
    `#{cmd}`
    returnValue = $?

    if returnValue != 0
      handleError("sortBam")
    end

    puts "Marking Duplicates"
    cmd = markDupCommand()
    `#{cmd}`
    returnValue = $?

    if returnValue != 0
      handleError("markBam")
    end

    if @filterPhix == true
       puts "Filtering out phix reads"
       cmd = filterPhixReadsCmd(@markedBam)
       `#{cmd}`
       returnValue = $?
    
      if returnValue != 0
        handleError("filterPhix")
      end
    end    

   if @isFragment == false
      puts "Fixing mate information"
      cmd = fixMateInfoCmd()
      `#{cmd}`
      returnValue = $?

      if returnValue != 0
        handleError("fixMateInfo")
      end
   end
 
   puts "Fixing CIGAR for unmapped reads"
   cmd = fixCIGARCmd(@markedBam) 
   `#{cmd}`
   returnValue = $?

   if returnValue != 0
     handleError("fixCIGAR")
   end

   puts "Calculating mapping stats"
   cmd = mappingStatsCmd()
   `#{cmd}`
   returnValue = $?

   if returnValue != 0
     handleError("bamAnalyzer")
   end
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
           @markedBam.to_s + " " + @picardTempDir + " MAX_RECORDS_IN_RAM=" + 
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
    errorDetails = getNodeCharacteristics()
    puts errorMessage.to_s
    puts errorDetails.to_s
    exit -1
  end

  # Method to print the free disk space on the temporary drive /space1/tmp on
  # each node, node name etc.
  def getNodeCharacteristics()
    result = "Current working directory : " + Dir.pwd
    # Get execution hostname
    cmd = "hostname"
    output = `#{cmd}`
    result = result + " Execution hostname : " + output.to_s
    cmd = "df -h /space1/tmp"
    output = `#{cmd}`
    result = result + " Free space on /space1/tmp = " + output.to_s
    return result
  end

  # Dump the characteristics of the execution host on the console output
  def displayNodeCharacteristics()
    result = getNodeCharacteristics()
    puts result.to_s
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
