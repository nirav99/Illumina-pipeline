#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'PipelineHelper'

class BWA_BAM
  def initialize(refPath)
    @reference      = refPath
    @sequenceFiles  = nil
    @sangerSeqFiles = nil # Sequence files with sanger qualities
    @isFragment     = false
    @bwaPath        = "/stornext/snfs5/next-gen/niravs_scratch/code/bwa_test/bwa_code/bwa-0.5.8a/bwa"
    @picardPath     = "/stornext/snfs5/next-gen/software/picard-tools/current"
    @picardTempDir  = "TMP_DIR=/space1/tmp"
    @picardValStr   = "VALIDATION_STRINGENCY=LENIENT"
    @illToSanger    = "/stornext/snfs5/next-gen/Illumina/ipipe/third_party/maq"
    @samFileName    = nil
    @bamFileName    = nil
    @sortedBam      = nil
    @markedBam      = nil
    @cpuCores       = 6
    @maxMemory      = 28000  # Maximum memory available per node
    @lessMemory     = 28000  # Command requiring less than maximum memory
    @priority       = "high" # Run with high priority (Run in high queue)
  
    # Instantiate pipeline helper 
    @helper        = PipelineHelper.new()
    @fcName        = @helper.findFCName()
    @laneNumber    = @helper.findAnalysisLaneNumbers()
    @fcAndLane     = @fcName + "-" + @laneNumber.to_s
    findSequenceFiles()
    generateSamFileName()

    puts @sequenceFiles
    puts "Sam Name = " + @samFileName
    puts "Bam Name = " + @bamFileName
    puts "Reference = " + @reference
  end

  def process()
    # Convert the quality values from Illumina format to Sanger format
    illToSangerRead1Cmd = illuminaToSangerCommand(@sequenceFiles[0], @sangerSeqFiles[0])
    objConvRead1 = Scheduler.new("Illumina_Sanger_Read1-" + @fcAndLane, illToSangerRead1Cmd)
    objConvRead1.setMemory(@maxMemory)
    objConvRead1.setNodeCores(@cpuCores)
    objConvRead1.setPriority(@priority)
    objConvRead1.runCommand()
    illSangerReadID1 = objConvRead1.getJobName()

    if @isFragment == false
      illToSangerRead2Cmd = illuminaToSangerCommand(@sequenceFiles[1], @sangerSeqFiles[1])
      objConvRead2 = Scheduler.new("Illumina_Sanger_Read1-" + @fcAndLane, illToSangerRead2Cmd)
      objConvRead2.setMemory(@maxMemory)
      objConvRead2.setNodeCores(@cpuCores)
      objConvRead2.setPriority(@priority)
      objConvRead2.runCommand()
      illSangerReadID2 = objConvRead2.getJobName()
    end

    outputFile1 = @sangerSeqFiles[0] + ".sai"

    alnCmd1 = buildAlignCommand(@sangerSeqFiles[0], outputFile1) 
    obj1 = Scheduler.new(@fcAndLane + "_aln_Read1", alnCmd1)
    obj1.setMemory(@maxMemory)
    obj1.setNodeCores(@cpuCores)
    obj1.setPriority(@priority)
    obj1.setDependency(illSangerReadID1)
    obj1.runCommand()
    alnJobID1 = obj1.getJobName()

    # paired end flowcell
    if @isFragment == false
      outputFile2 = @sangerSeqFiles[1] + ".sai"
      alnCmd2 = buildAlignCommand(@sangerSeqFiles[1], outputFile2)
      obj2 = Scheduler.new(@fcAndLane + "_aln_Read2", alnCmd2)
      obj2.setMemory(@maxMemory)
      obj2.setNodeCores(@cpuCores)
      obj2.setPriority(@priority)
      obj2.setDependency(illSangerReadID2)
      obj2.runCommand()
      alnJobID2 = obj2.getJobName()

      sampeCmd = buildSampeCommand(outputFile1, outputFile2, @sangerSeqFiles[0],
                                   @sangerSeqFiles[1])
      obj3 = Scheduler.new(@fcAndLane + "_sampe", sampeCmd)
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
      samseCmd = buildSamseCommand(outputFile1, @sangerSeqFiles[0])
      obj3 = Scheduler.new(@fcAndLane + "_samse", samseCmd)
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
    obj4 = Scheduler.new(@fcAndLane + "_toBam", addRGCmd)
    obj4.setMemory(@lessMemory)
    obj4.setNodeCores(1)
    obj4.setPriority(@priority)
    obj4.setDependency(makeSamJobName)
    obj4.runCommand()
    addRGJobName = obj4.getJobName()

    # Sort a BAM
    sortBamCmd = sortBamCommand()
    obj5 = Scheduler.new(@fcAndLane  + "_sortBam", sortBamCmd)
    obj5.setMemory(@lessMemory)
    obj5.setNodeCores(1)
    obj5.setPriority(@priority)
    obj5.setDependency(addRGJobName)
    obj5.runCommand()
    sortBamJobName = obj5.getJobName() 

    # Mark duplicates on BAM
    markedDupCmd = markDupCommand()
    obj6 = Scheduler.new(@fcAndLane + "_markDupBam", markedDupCmd)
    obj6.setMemory(@lessMemory)
    obj6.setNodeCores(1)
    obj6.setPriority(@priority)
    obj6.setDependency(sortBamJobName)
    obj6.runCommand()
    markedDupJobName = obj6.getJobName()

    # Filter out phix reads
    phixFilterCmd = filterPhixReadsCmd()
    objX = Scheduler.new(@fcAndLane + "_phixFilter", phixFilterCmd)
    objX.setMemory(@lessMemory)
    objX.setNodeCores(1)
    objX.setPriority(@priority)
    objX.setDependency(markedDupJobName)
    objX.runCommand()
    phixFilterJobName = objX.getJobName()

    # Fix mate information for paired end FC
    if @isFragment == false
      fixMateCmd = fixMateInfoCmd()
      objY = Scheduler.new(@fcAndLane + "_fixMateInfo" + @markedBam, fixMateCmd)
      objY.setMemory(@lessMemory)
      objY.setNodeCores(1)
      objY.setPriority(@priority)
      objY.setDependency(phixFilterJobName)
      objY.runCommand()
      fixMateJobName = objY.getJobName()
    end

    # Calculate Alignment Stats
    mappingStatsCmd = calculateMappingStats()
    obj7 = Scheduler.new(@fcAndLane + "_AlignStats", mappingStatsCmd)
    obj7.setMemory(@lessMemory)
    obj7.setNodeCores(1)
    obj7.setPriority(@priority)
    
    if @isFragment == false
      obj7.setDependency(fixMateJobName)
    else
      obj7.setDependency(phixFilterJobName)
    end

    obj7.runCommand()
    runStatsJobName = obj7.getJobName()

    # Hook to run code after final BAM is generated
    postRunCmd = "ruby " + File.dirname(__FILE__) + "/bwa_postrun.rb"
    obj8 = Scheduler.new(@fcAndLane + "_post_run", postRunCmd)
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

    @sangerSeqFiles = Array.new
    @sequenceFiles.each do |seqFile|
      @sangerSeqFiles << seqFile.gsub(/sequence/, "sanger_sequence")
    end

    puts "List of sanger quality file names"
    @sangerSeqFiles.each do |line|
      puts line
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

  # Method to convert basecalls qualities from Illumina to Sanger format
  def illuminaToSangerCommand(illuminaSeqFile, sangerSeqFile)
    cmd = @illToSanger + " sol2sanger " + illuminaSeqFile + " " + sangerSeqFile
    return cmd
  end

  def addRGTagCommand()
    cmd = "java -Xmx8G -jar /stornext/snfs5/next-gen/Illumina/ipipe/java" +
          "/AddRGToBam.jar Input=" + @samFileName.to_s + " Output=" + @bamFileName.to_s +
          " RGTag=0 "
    sampleID = @fcName.to_s + "-" + @laneNumber.to_s

    if sampleID == nil || sampleID.empty?()
      sampleID = "unknown"
    end
    cmd = cmd + "SampleID=" + sampleID.to_s + " Program=BWA Version=0.5.8 " +
                "Platform=Illumina"

    if File::exist?("libraryName")
      libraryName = IO.readlines("libraryName")[0].strip
      cmd = cmd + " Library=" + libraryName.to_s 
    end
    return cmd
  end

  def sortBamCommand()
    cmd = "java -Xmx8G -jar " + @picardPath + "/SortSam.jar I=" + @bamFileName +
    " O=" + @sortedBam + " SO=coordinate " + @picardTempDir + " " +
    " MAX_RECORDS_IN_RAM=1000000 " + @picardValStr
    return cmd
  end

  def markDupCommand()
    cmd = "java -Xmx8G -jar " + @picardPath + "/MarkDuplicates.jar I=" +
          @sortedBam + " O=" + @markedBam + " " + @picardTempDir + " " +
          "MAX_RECORDS_IN_RAM=1000000 AS=true M=metrics.foo " +
          @picardValStr 
    return cmd
  end

  # Method to calculate Mapping Stats
  def calculateMappingStats()
    cmd = "ruby " + File.dirname(__FILE__) +  "/BWAMapStats.rb " + @markedBam
    puts "Command to generate Mapping Stats : " + cmd
    return cmd
  end

  def filterPhixReadsCmd()
    cmd = "ruby " +  File.dirname(__FILE__) + "/PhixFilterFromBAM.rb " + @markedBam
    puts "Command to filter out phix reads : " + cmd
    return cmd
  end
 
  def fixMateInfoCmd()
    cmd = "java -Xmx8G -jar " + @picardPath + "/FixMateInformation.jar I=" + @markedBam.to_s +
          " " + @picardTempDir + " MAX_RECORDS_IN_RAM=1000000 " + @picardValStr
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
