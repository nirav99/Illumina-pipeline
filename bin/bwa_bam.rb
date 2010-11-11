#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'PipelineHelper'

class BWA_BAM
  def initialize(refPath)
    @reference     = refPath
    @sequenceFiles = nil
    @isFragment    = false
    @bwaPath       = "/stornext/snfs5/next-gen/niravs_scratch/code/bwa_test/bwa_code/bwa-0.5.8a/bwa"
    @picardPath    = "/stornext/snfs5/next-gen/software/picard-tools/current"
    @samFileName   = nil
    @bamFileName   = nil
    @sortedBam     = nil
    @markedBam     = nil
    @cpuCores      = 8
    @maxMemory     = 28000 # Maximum memory available per node
    @lessMemory    = 28000  # Command requiring less than maximum memory
    @priority      = "high" # Run with high priority (Run in high queue)
  
    # Instantiate pipeline helper 
    @helper        = PipelineHelper.new()
    @fcName        = @helper.findFCName()

    findSequenceFiles()
    generateSamFileName()

    puts @sequenceFiles
    puts "Sam Name = " + @samFileName
    puts "Bam Name = " + @bamFileName
    puts "Reference = " + @reference
  end

  def process()
    outputFile1 = @sequenceFiles[0] + ".sai"

    alnCmd1 = buildAlignCommand(@sequenceFiles[0], outputFile1) 
    obj1 = Scheduler.new(@fcName + "_" + @sequenceFiles[0], alnCmd1)
    obj1.setMemory(@maxMemory)
    obj1.setNodeCores(@cpuCores)
    obj1.setPriority(@priority)
    obj1.runCommand()
    alnJobID1 = obj1.getJobName()

    # paired end flowcell
    if @isFragment == false
      outputFile2 = @sequenceFiles[1] + ".sai"
      alnCmd2 = buildAlignCommand(@sequenceFiles[1], outputFile2)
      obj2 = Scheduler.new(@fcName + "_" + @sequenceFiles[1], alnCmd2)
      obj2.setMemory(@maxMemory)
      obj2.setNodeCores(@cpuCores)
      obj2.setPriority(@priority)
      obj2.runCommand()
      alnJobID2 = obj2.getJobName()

      sampeCmd = buildSampeCommand(outputFile1, outputFile2, @sequenceFiles[0],
                                   @sequenceFiles[1])
      obj3 = Scheduler.new(@fcName + "_" + @samFileName, sampeCmd)
      obj3.setMemory(@lessMemory)
#      obj3.setNodeCores(@cpuCores)
      obj3.setNodeCores(1)
      obj3.setPriority(@priority)
      obj3.setDependency(alnJobID1)
      obj3.setDependency(alnJobID2)
      obj3.runCommand()
      makeSamJobName = obj3.getJobName()
    else
      # Flowcell is fragment
      samseCmd = buildSamseCommand(outputFile1, @sequenceFiles[0])
      obj3 = Scheduler.new(@fcName + "_" + @samFileName, samseCmd)
      obj3.setMemory(@lessMemory)
#      obj3.setNodeCores(@cpuCores)
      obj3.setNodeCores(1)
      obj3.setPriority(@priority)
      obj3.setDependency(alnJobID1)
      obj3.runCommand()
      makeSamJobName = obj3.getJobName()
    end

    # Add RG header and convert to BAM
    addRGCmd = addRGTagCommand() 
    obj4 = Scheduler.new(@fcName + "_" + @bamFileName, addRGCmd)
    obj4.setMemory(@lessMemory)
    obj4.setNodeCores(1)
    obj4.setPriority(@priority)
    obj4.setDependency(makeSamJobName)
    obj4.runCommand()
    addRGJobName = obj4.getJobName()

    # Sort a BAM
    sortBamCmd = sortBamCommand()
    obj5 = Scheduler.new(@fcName + "_" + @sortedBam, sortBamCmd)
    obj5.setMemory(@lessMemory)
    obj5.setNodeCores(1)
    obj5.setPriority(@priority)
    obj5.setDependency(addRGJobName)
    obj5.runCommand()
    sortBamJobName = obj5.getJobName() 

    # Mark duplicates on BAM
    markedDupCmd = markDupCommand()
    obj6 = Scheduler.new(@fcName + "_" + @markedBam, markedDupCmd)
    obj6.setMemory(@lessMemory)
    obj6.setNodeCores(1)
    obj6.setPriority(@priority)
    obj6.setDependency(sortBamJobName)
    obj6.runCommand()
    markedDupJobName = obj6.getJobName()

    # Filter out phix reads
    phixFilterCmd = filterPhixReadsCmd()
    objX = Scheduler.new(@fcName + "_phix_filter_" + @markedBam, phixFilterCmd)
    objX.setMemory(@lessMemory)
    objX.setNodeCores(1)
    objX.setPriority(@priority)
    objX.setDependency(markedDupJobName)
    objX.runCommand()
    phixFilterJobName = objX.getJobName()

    # Calculate Alignment Stats
    mappingStatsCmd = calculateMappingStats()
    obj7 = Scheduler.new(@fcName + "_" + @markedBam + "_BAM_Stats", mappingStatsCmd)
    obj7.setMemory(@lessMemory)
    obj7.setNodeCores(1)
    obj7.setPriority(@priority)
#    obj7.setDependency(markedDupJobName)
    obj7.setDependency(phixFilterJobName)
    obj7.runCommand()
    runStatsJobName = obj7.getJobName()

    # Hook to run code after final BAM is generated
    postRunCmd = "ruby " + File.dirname(__FILE__) + "/bwa_postrun.rb"
    obj8 = Scheduler.new(@fcName + "_post_run", postRunCmd)
    obj8.setMemory(2000)
    obj8.setNodeCores(1)
    obj8.setPriority(@priority)
    obj8.setDependency(runStatsJobName)
    obj8.runCommand()
  end

  private
  def findSequenceFiles()
    # Assumption - 1 directory per lane
    fileList = Dir["*_sequence.txt"]

    if fileList.size < 1
      raise "Could not find sequence files in directory " + Dir.pwd
    elsif fileList.size == 1
      @isFragment = true
      @sequenceFiles = fileList
    elsif fileList.size == 2
      @isFragment = false # paired end read
      @sequenceFiles = fileList
    else
      raise "More than two sequence files detected, perhaps from different reads in directory " + Dir.pwd
    end
  end
 
  def generateSamFileName()
    prefix = @sequenceFiles[0].slice(/s_\d/)
    @samFileName = prefix + ".sam"
    @bamFileName = prefix + ".bam"
    @sortedBam   = prefix + "_sorted.bam"
    @markedBam   = prefix + "_marked.bam"
  end

  # BWA aln command - configured to run on 8 cores
  def buildAlignCommand(readFile, outputFile)
    cmd = @bwaPath + " aln -t " + @cpuCores.to_s + " " + @reference + " " + readFile + " > " +
          outputFile
    return cmd
  end

  # BWA sampe command - for use with paired end reads
  # read1File - sai file for read1
  # read2File - sai file for read2
  # read1Seq  - sequence file for read1
  # read2Seq  - sequence file for read2
  def buildSampeCommand(read1File, read2File, read1Seq, read2Seq)
    puts "BWA command"
    puts @bwaPath
    puts @reference
    puts read1File + " " + read2File
    puts read1Seq + " " + read2Seq
    puts @samFileName
    cmd = @bwaPath + " sampe " + @reference + " " + read1File + " " + read2File +
           " " + read1Seq + " " + read2Seq + " > " + @samFileName.to_s
    puts cmd
    return cmd
  end

  # BWA samse command - for use with fragment reads
  # read1File - sai file for read1
  # read1Seq  - sequence file for read1
  def buildSamseCommand(read1File, read1Seq)
    cmd = @bwaPath + " samse " + @reference + " " + read1File + " " + read1Seq + " > " + @samFileName
    return cmd
  end

  def addRGTagCommand()
    cmd = "java -Xmx4G -jar /stornext/snfs5/next-gen/niravs_scratch/code/AddRGToBam" +
          "/AddRGToBam.jar Input=" + @samFileName.to_s + " Output=" + @bamFileName.to_s +
          " RGTag=0 SampleID=unknown"
    return cmd
  end

  def sortBamCommand()
    cmd = "java -Xmx8G -jar " + @picardPath + "/SortSam.jar I=" + @bamFileName +
    " O=" + @sortedBam + " SO=coordinate TMP_DIR=/space1/tmp " +
    " MAX_RECORDS_IN_RAM=1000000 VALIDATION_STRINGENCY=LENIENT"
    return cmd
  end

  def markDupCommand()
    cmd = "java -Xmx8G -jar " + @picardPath + "/MarkDuplicates.jar I=" +
          @sortedBam + " O=" + @markedBam + " TMP_DIR=/space1/tmp " +
          "MAX_RECORDS_IN_RAM=1000000 AS=true M=metrics.foo " +
          "VALIDATION_STRINGENCY=LENIENT" 
    return cmd
  end

  # Method to calculate Mapping Stats
  def calculateMappingStats()
    cmd = "ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/BWAMapStats.rb " + @markedBam
    puts "Command to generate Mapping Stats : " + cmd
    return cmd
  end

  def filterPhixReadsCmd()
    cmd = "ruby " +  File.dirname(__FILE__) + "/PhixFilterFromBAM.rb"
    puts "Command to filter out phix reads : " + cmd
    return cmd
  end
 
  @reference     = nil   # Reference path
  @sequenceFiles = nil   # Array of sequence files
  @isFragment    = false # Is read fragment, default is paired (true)
  @samFileName   = nil   # Name of SAM file to generate using BWA
  @bamFileName   = nil   # Name of BAM file with RG tag
  @sortedBam     = nil   # Name of sorted BAM
  @markedBam     = nil   # Name of BAM with duplicates marked
  @bwaPath       = nil   # Path to BWA
  @picardPath    = nil   # Picard path
  @cpuCores      = 8     # Processor cores
  @priority      = "normal" # Execution priority
  @helper        = nil   # PipelineHelper instance
  @fcName        = ""    # Flowcell name
end 


# Instantiate the BWA_BAM class while specifying the reference fasta file as the
# parameter
obj = BWA_BAM.new(ARGV[0])
obj.process()
