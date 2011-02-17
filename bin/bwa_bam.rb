#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'PipelineHelper'
require 'BWAParams'

class BWA_BAM
  def initialize()
    # Open BWAConfigParams.txt file and read configuration parameters for BWA
    bwaParams = BWAParams.new()
    bwaParams.loadFromFile()
    @reference   = bwaParams.getReferencePath()  # Reference path
    @filterPhix  = bwaParams.filterPhix?()       # Whether to filter phix reads
    @libraryName = bwaParams.getLibraryName()    # Obtain library name
    @chipDesign  = bwaParams.getChipDesignName() # Chip design name for capture
                                                 # stats calculation
    @sampleName  = bwaParams.getSampleName()     # Sample name

    if @reference == nil || @reference.empty?()
      raise "Error : Reference path MUST be specified"
    end

    if @chipDesign != nil && !@chipDesign.empty?()
      puts "Chip Design = " + @chipDesign.to_s
    end

    # Computing cluster specific members
    @cpuCores       = 6      # Max CPU cores to use
    @minCpuCores    = 6      # Min CPU cores to use
    # Note: Maximum available CPU cores are 8. However, due to ardmore
    # idiosyncracies, jobs requesting 8 cores wait for more than a day to obtain
    # a node. Thus, selected 6 as the max CPU cores based on the observation
    # that jobs requesting 6 cores easily find a node
    @maxMemory      = 28000  # Maximum memory available per node
    @lessMemory     = 28000  # Command requiring less than maximum memory
    @priority       = "high" # Run with high priority (Run in high queue)
  
    # List of required paths
    # Path to BWA executable
    @bwaPath         = "/stornext/snfs5/next-gen/niravs_scratch/code/bwa_test/bwa_0_5_9/bwa-0.5.9/bwa"
    # Directory hosting various custom-built jars
    @javaDir         = "/stornext/snfs5/next-gen/Illumina/ipipe/java"

    # Parameters for picard commands
    @picardPath       = "/stornext/snfs5/next-gen/software/picard-tools/current"
    @picardValStr     = "VALIDATION_STRINGENCY=LENIENT"
    # Name of temp directory used by picard
    @picardTempDir   = "TMP_DIR=/space1/tmp"
    # Number of records to hold in RAM
    @maxRecordsInRam = 2000000
    # Maximum Java heap size
    @heapSize        = "-Xmx12G"

    @sequenceFiles  = nil # Sequence files with Illumina qualities

    # Whether flowcell is paired-end or fragment
    @isFragment     = false

    # Name of SAM/BAM files to be generated during the workflow
    @samFileName    = nil # SAM file generated by BWA
    @sortedBam      = nil # Coordinate sorted BAM file
    @markedBam      = nil # Coordinate sorted BAM with duplicates marked

    # Instantiate pipeline helper 
    @helper        = PipelineHelper.new()
    @fcName        = @helper.findFCName()
    @laneNumber    = @helper.findAnalysisLaneNumbers()
    @fcAndLane     = @fcName + "-" + @laneNumber.to_s
    findSequenceFiles()
    generateSamFileName()

    puts @sequenceFiles
    puts "Sam Name  = " + @samFileName
    puts "Reference = " + @reference
  end

  # Create jobs to generate alignment
  def process()
    # For lanes that don't need alignment, run post run and exit
    if @reference.eql?("sequence")
      puts "No alignment to perform since reference is \"sequence\""
      puts "Running postrun script"
      runPostRunCmd("")
      exit 0
    end

    outputFile1 = @sequenceFiles[0] + ".sai"

    alnCmd1 = buildAlignCommand(@sequenceFiles[0], outputFile1) 
    obj1 = Scheduler.new(@fcAndLane + "_aln_Read1", alnCmd1)
    obj1.setMemory(@maxMemory)
    obj1.setNodeCores(@cpuCores)
    obj1.setPriority(@priority)
    obj1.runCommand()
    alnJobID1 = obj1.getJobName()

    # paired end flowcell
    if @isFragment == false
      outputFile2 = @sequenceFiles[1] + ".sai"
      alnCmd2 = buildAlignCommand(@sequenceFiles[1], outputFile2)
      obj2 = Scheduler.new(@fcAndLane + "_aln_Read2", alnCmd2)
      obj2.setMemory(@maxMemory)
      obj2.setNodeCores(@cpuCores)
      obj2.setPriority(@priority)
      obj2.runCommand()
      alnJobID2 = obj2.getJobName()

      sampeCmd = buildSampeCommand(outputFile1, outputFile2, @sequenceFiles[0],
                                   @sequenceFiles[1])
      obj3 = Scheduler.new(@fcAndLane + "_sampe", sampeCmd)
      obj3.setMemory(@lessMemory)
#      obj3.setNodeCores(@cpuCores)
      obj3.setNodeCores(@minCpuCores)
      obj3.setPriority(@priority)
      obj3.setDependency(alnJobID1)
      obj3.setDependency(alnJobID2)
      obj3.runCommand()
      makeSamJobName = obj3.getJobName()
    else
      # Flowcell is fragment
      samseCmd = buildSamseCommand(outputFile1, @sequenceFiles[0])
      obj3 = Scheduler.new(@fcAndLane + "_samse", samseCmd)
      obj3.setMemory(@lessMemory)
#      obj3.setNodeCores(@cpuCores)
      obj3.setNodeCores(@minCpuCores)
      obj3.setPriority(@priority)
      obj3.setDependency(alnJobID1)
      obj3.runCommand()
      makeSamJobName = obj3.getJobName()
    end

    # Sort a BAM
    sortBamCmd = sortBamCommand()
    obj5 = Scheduler.new(@fcAndLane  + "_sortBam", sortBamCmd)
    obj5.setMemory(@lessMemory)
    obj5.setNodeCores(@minCpuCores)
    obj5.setPriority(@priority)
    obj5.setDependency(makeSamJobName)
    obj5.runCommand()
    sortBamJobName = obj5.getJobName() 

    # Mark duplicates on BAM
    markedDupCmd = markDupCommand()
    obj6 = Scheduler.new(@fcAndLane + "_markDupBam", markedDupCmd)
    obj6.setMemory(@lessMemory)
    obj6.setNodeCores(@minCpuCores)
    obj6.setPriority(@priority)
    obj6.setDependency(sortBamJobName)
    obj6.runCommand()
    markedDupJobName = obj6.getJobName()
    prevCmd = markedDupJobName

    # Filter out phix reads
    if @filterPhix == true
      phixFilterCmd = filterPhixReadsCmd(@markedBam)
      objX = Scheduler.new(@fcAndLane + "_phixFilter", phixFilterCmd)
      objX.setMemory(@lessMemory)
      objX.setNodeCores(@minCpuCores)
      objX.setPriority(@priority)
      objX.setDependency(prevCmd)
      objX.runCommand()
      phixFilterJobName = objX.getJobName()
      prevCmd = phixFilterJobName
    end

    # Fix mate information for paired end FC
    if @isFragment == false
      fixMateCmd = fixMateInfoCmd()
      objY = Scheduler.new(@fcAndLane + "_fixMateInfo" + @markedBam, fixMateCmd)
      objY.setMemory(@lessMemory)
      objY.setNodeCores(@minCpuCores)
      objY.setPriority(@priority)
      objY.setDependency(prevCmd)
      objY.runCommand()
      fixMateJobName = objY.getJobName()
      prevCmd = fixMateJobName
    end

    # Fix unmapped reads. When a read aligns over the boundary of two
    # chromosomes, BWA marks this read as unmapped but does not reset CIGAR to *
    # and mapping quality zero. This causes picard's validator to complain.
    # Hence, we fix that anomaly here.
    fixCIGARCmd = buildFixCIGARCmd(@markedBam)
    fixCIGARObj = Scheduler.new(@fcAndLane + "_fixCIGAR" + @markedBam, fixCIGARCmd)
    fixCIGARObj.setMemory(@lessMemory)
    fixCIGARObj.setNodeCores(@minCpuCores)
    fixCIGARObj.setPriority(@priority)
    fixCIGARObj.setDependency(prevCmd)
    fixCIGARObj.runCommand()
    fixCIGARJobName = fixCIGARObj.getJobName()
    prevCmd = fixCIGARJobName

    # Calculate Alignment Stats
    mappingStatsCmd = calculateMappingStats()
    obj7 = Scheduler.new(@fcAndLane + "_AlignStats", mappingStatsCmd)
    obj7.setMemory(@lessMemory)
    obj7.setNodeCores(@minCpuCores)
    obj7.setPriority(@priority)
    obj7.setDependency(prevCmd)
    obj7.runCommand()
    runStatsJobName = obj7.getJobName()
    prevCmd = runStatsJobName

    if @chipDesign != nil && !@chipDesign.empty?()
      captureStatsCmd = buildCaptureStatsCmd()
      capStatsObj = Scheduler.new(@fcAndLane + "_CaptureStats", captureStatsCmd)
      capStatsObj.setMemory(@lessMemory)
      capStatsObj.setNodeCores(@minCpuCores)
      capStatsObj.setPriority(@priority)
      capStatsObj.setDependency(prevCmd)
      capStatsObj.runCommand()
      capStatsJobName = capStatsObj.getJobName()
      prevCmd = capStatsJobName
    end

    # Hook to run code after final BAM is generated
    runPostRunCmd(prevCmd)
  end

  private
  # Method to find sequence file names in the GERALD directory
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
 
  # Method to generate names of various BAM and SAM files
  def generateSamFileName()
    prefix = @sequenceFiles[0].slice(/s_\d/)
    @samFileName = prefix + ".sam"
    @sortedBam   = prefix + "_sorted.bam"
    @markedBam   = prefix + "_marked.bam"
  end

  # BWA aln command - configured to run on 8 cores
  def buildAlignCommand(readFile, outputFile)
    cmd = "time " + @bwaPath + " aln -t " + @cpuCores.to_s + " -I " +
           @reference + " " + readFile + " > " + outputFile
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
    cmd = "time " + @bwaPath + " sampe -P " + 
          " -r " + buildRGString() + " " + @reference + " " +
           read1File + " " + read2File + " " + read1Seq + " " + read2Seq +
           " > " + @samFileName.to_s
    puts cmd
    return cmd
  end

  # BWA samse command - for use with fragment reads
  # read1File - sai file for read1
  # read1Seq  - sequence file for read1
  def buildSamseCommand(read1File, read1Seq)
    cmd = "time " + @bwaPath + " samse " + " -r " + buildRGString() +
          " " + @reference + " " + read1File + " " +
          read1Seq + " > " + @samFileName
    return cmd
  end

  # Method to build RG string in the format expected by BWA sampe
  # and samse commands
  def buildRGString()
    # If sample name was provided in the configuration parameters, use it.
    # If not, use FC-lane as the sample name. If that also is not availble
    # use the string "unknown" as the sampleID
    if @sampleName != nil && !@sampleName.empty?()
       sampleID = @sampleName.to_s
    elsif @fcName != nil && !@fcName.empty?()
       sampleID = @fcName.to_s
       if @laneNumber != nil && !@laneNumber.to_s.empty?()
          sampleID = sampleID + "-" + @laneNumber.to_s
       end
    else
       sampleID = "unknown"
    end
     
    rgString = "'@RG\\tID:0\\tSM:" + sampleID

    if @libraryName != nil && !@libraryName.empty?()
      rgString = rgString + "\\tLB:" + @libraryName.to_s
    end

    rgString = rgString + "'"
    return rgString.to_s
  end

  # Sort the BAM by mapping coordinates
  def sortBamCommand()
    cmd = "time java " + @heapSize + " -jar " + @picardPath + "/SortSam.jar I=" + @samFileName +
    " O=" + @sortedBam + " SO=coordinate " + @picardTempDir + " " +
    " MAX_RECORDS_IN_RAM=" + @maxRecordsInRam.to_s + " " + @picardValStr
    return cmd
  end

  # Mark duplicates on a sorted BAM
  def markDupCommand()
    cmd = "time java " + @heapSize + " -jar " + @picardPath + "/MarkDuplicates.jar I=" +
          @sortedBam + " O=" + @markedBam + " " + @picardTempDir + " " +
          "MAX_RECORDS_IN_RAM=" + @maxRecordsInRam.to_s + " AS=true M=metrics.foo " +
          @picardValStr 
    return cmd
  end

  # Method to build command to calculate mapping stats
  def calculateMappingStats()
    cmd = "ruby " + File.dirname(__FILE__) +  "/BWAMapStats.rb " + @markedBam
    puts "Command to generate Mapping Stats : " + cmd
    return cmd
  end

  # Filter reads mapping to phix and phix contig from the BAM header
  def filterPhixReadsCmd(bamFile)
    jarName = @javaDir + "/PhixFilterFromBAM.jar"
    cmd = "time java " + @heapSize + " -jar " + jarName + " I=" + bamFile
    return cmd
  end
 
  # Correct the flag describing the strand of the mate
  def fixMateInfoCmd()
    cmd = "time java " + @heapSize + " -jar " + @picardPath + "/FixMateInformation.jar I=" +
           @markedBam.to_s + " " + @picardTempDir +
           " MAX_RECORDS_IN_RAM=" + @maxRecordsInRam.to_s + " " + @picardValStr
    return cmd
  end

  # Correct the unmapped reads. Reset CIGAR to * and mapping quality to zero.
  def buildFixCIGARCmd(bamFile)
    jarName = @javaDir + "/FixCIGAR.jar"
    cmd = "time java " + @heapSize + " -jar " + jarName + " I=" + bamFile
    return cmd
  end

  # Method to build command to generate capture stats
  def buildCaptureStatsCmd()
    cmd = "ruby " + File.dirname(__FILE__) + "/CaptureStats.rb " + @markedBam + 
          " " + @chipDesign
    puts "Command to calculate capture stats " + cmd
    return cmd
  end

  # Command to run after BWA alignment is completed
  def runPostRunCmd(previousJobName)
    postRunCmd = "ruby " + File.dirname(__FILE__) + "/bwa_postrun.rb"
    objPostRun = Scheduler.new(@fcAndLane + "_post_run", postRunCmd)
    objPostRun.setMemory(2000)
    objPostRun.setNodeCores(1)
    objPostRun.setPriority(@priority)
    if previousJobName != nil && !previousJobName.empty?() 
      objPostRun.setDependency(previousJobName)
    end
    objPostRun.runCommand()
  end

  @reference     = nil   # Reference path
  @sequenceFiles = nil   # Array of sequence files
  @isFragment    = false # Is read fragment, default is paired (true)
  @samFileName   = nil   # Name of SAM file to generate using BWA
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
obj = BWA_BAM.new()
obj.process()
