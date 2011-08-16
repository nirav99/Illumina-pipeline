#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'PipelineHelper'
require 'BWAParams'
require 'FCBarcodeFinder'
require 'yaml'

# Class to perform alignment on Illumina sequence files and generate a BAM using
# BWA.
# Author Nirav Shah niravs@bcm.edu

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
    @rgPUField   = bwaParams.getRGPUField()      # PU field for RG tag

    @fcBarcode   = bwaParams.getFCBarcode()      # Flowcell barcode
   
    # Retrieve Flowcell barcode either from the BWAParams file or from config files
    # in the GERALD directory. 
    if @fcBarcode == nil || @fcBarcode.empty?()

      # Instantiate pipeline helper 
      @helper       = PipelineHelper.new()
      fcName        = @helper.findFCName()
      laneNumber    = @helper.findAnalysisLaneNumbers()
      @fcAndLane    = fcName + "-" + laneNumber.to_s

      begin
        fcBcFinder   = FCBarcodeFinder.new
        @fcBarcode   = fcBcFinder.getBarcodeForLIMS()
      rescue
        if @fcBarcode == nil || @fcBarcode.empty?()
           @fcBarcode = @fcAndLane.to_s
        end
      end
    end

    # Priority in scheduling queue
    @priority    = bwaParams.getSchedulingQueue()

    if @reference == nil || @reference.empty?()
      raise "Error : Reference path MUST be specified"
    end

    if @chipDesign != nil && !@chipDesign.empty?()
      puts "Chip Design = " + @chipDesign.to_s
    end

    # Computing cluster specific members
    @cpuCores       = 8      # Max CPU cores to use
    @minCpuCores    = 8      # Min CPU cores to use
    @maxMemory      = 28000  # Maximum memory available per node
    @lessMemory     = 28000  # Command requiring less than maximum memory

    yamlConfigFile = File.dirname(File.dirname(__FILE__)) + "/config/config_params.yml" 
    @configReader = YAML.load_file(yamlConfigFile)
    @bwaPath = @configReader["bwa"]["path"]
   
    puts "BWA PATH = " + @bwaPath.to_s

    # Directory hosting various custom-built jars
    @javaDir         = File.dirname(File.dirname(__FILE__)) + "/java"

    @sequenceFiles  = nil   # Sequence files 
    @seqFilesZipped = false # Whether sequence files are zipped

    # Whether flowcell is paired-end or fragment
    @isFragment     = false

    # Name of SAM/BAM files to be generated during the workflow
    @samFileName    = nil # SAM file generated by BWA
    @sortedBam      = nil # Coordinate sorted BAM file
    @markedBam      = nil # Coordinate sorted BAM with duplicates marked

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

    if @seqFilesZipped == true
      unzipCmd1 = buildUnzipCommand()
      objUnzip1 = Scheduler.new(@fcBarcode + "_unzip_sequences", unzipCmd1)
      objUnzip1.setMemory(2000)
      objUnzip1.setNodeCores(1)
      objUnzip1.setPriority(@priority)
      objUnzip1.runCommand()
      unzipJobID1 = objUnzip1.getJobName()

      # Remove the suffix .bz2 from the sequence file names to prevent any
      # errors downstream
      idx = 0
      while idx < @sequenceFiles.length
        @sequenceFiles[idx].gsub!(/\.bz2$/, "")
        idx = idx + 1
      end
    else
      unzipJobID1 = ""
    end

    outputFile1 = @sequenceFiles[0] + ".sai"

    alnCmd1 = buildAlignCommand(@sequenceFiles[0], outputFile1) 
    obj1 = Scheduler.new(@fcBarcode + "_aln_Read1", alnCmd1)
    obj1.lockWholeNode(@priority)

    if !unzipJobID1.empty?()
      obj1.setDependency(unzipJobID1)
    end
    obj1.runCommand()
    alnJobID1 = obj1.getJobName()

    # paired end flowcell
    if @isFragment == false
      outputFile2 = @sequenceFiles[1] + ".sai"
      alnCmd2 = buildAlignCommand(@sequenceFiles[1], outputFile2)
      obj2 = Scheduler.new(@fcBarcode + "_aln_Read2", alnCmd2)
      obj2.lockWholeNode(@priority)

      if !unzipJobID1.empty?()
        obj2.setDependency(unzipJobID1)
      end

      obj2.runCommand()
      alnJobID2 = obj2.getJobName()

      sampeCmd = buildSampeCommand(outputFile1, outputFile2, @sequenceFiles[0],
                                   @sequenceFiles[1])
      obj3 = Scheduler.new(@fcBarcode + "_sampe", sampeCmd)
      obj3.lockWholeNode(@priority)
      obj3.setDependency(alnJobID1)
      obj3.setDependency(alnJobID2)
      obj3.runCommand()
      makeSamJobName = obj3.getJobName()
    else
      # Flowcell is fragment
      samseCmd = buildSamseCommand(outputFile1, @sequenceFiles[0])
      obj3 = Scheduler.new(@fcBarcode + "_samse", samseCmd)
      obj3.lockWholeNode(@priority)
      obj3.setDependency(alnJobID1)
      obj3.runCommand()
      makeSamJobName = obj3.getJobName()
    end

    # Generate a BAM, sort it, mark dups on it and calculate mapping stats
    bamProcessCmd = buildBAMProcessingCmd()
    obj4 = Scheduler.new(@fcBarcode + "_processBam", bamProcessCmd)
    obj4.lockWholeNode(@priority)
    obj4.setDependency(makeSamJobName)
    obj4.runCommand()
    previousJobName = obj4.getJobName() 

    if @chipDesign != nil && !@chipDesign.empty?()
      captureStatsCmd = buildCaptureStatsCmd()
      capStatsObj = Scheduler.new(@fcBarcode + "_CaptureStats", captureStatsCmd)
      capStatsObj.lockWholeNode(@priority)
      capStatsObj.setDependency(previousJobName)
      capStatsObj.runCommand()
      capStatsJobName = capStatsObj.getJobName()
      previousJobName = capStatsJobName
    end

    # Hook to run code after final BAM is generated
    runPostRunCmd(previousJobName)
  end

  private
  # Method to find sequence file names in the GERALD directory
  def findSequenceFiles()
    # Assumption - 1 directory per lane
    fileList = Dir["*_sequence.txt"]

    if fileList == nil || fileList.size < 1
      fileList = Dir["*_sequence.txt.bz2"]
    end

    if fileList.size < 1
      raise "Could not find sequence files in directory " + Dir.pwd
    elsif fileList.size == 1
      @isFragment = true
      @sequenceFiles = fileList
    elsif fileList.size == 2
        @sequenceFiles = Array.new
      if fileList[0].match(/s_\d_1_/)
        @sequenceFiles[0] = fileList[0]
        @sequenceFiles[1] = fileList[1]
      else
        @sequenceFiles[0] = fileList[1]
        @sequenceFiles[1] = fileList[0]
      end
      @isFragment = false # paired end read

    else
      raise "More than two sequence files detected, perhaps from different reads in directory " + Dir.pwd
    end
     puts @sequenceFiles

     @sequenceFiles.each do |seqFile|
       if seqFile.match(/\.bz2$/)
         puts "Zipped sequence file"
         @seqFilesZipped = true
       end
     end
  end

  def buildUnzipCommand()
    cmd = "bzip2 -d "

    @sequenceFiles.each do |seqFile|
      cmd = cmd + seqFile + " "
    end
    return cmd
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
    currentTime = Time.new

    # If sample name was provided in the configuration parameters, use it.
    # If not, use FC-barcode as the sample name. 
    if @sampleName != nil && !@sampleName.empty?()
       sampleID = @sampleName.to_s
    else
       sampleID = @fcBarcode.to_s
    end
     
    rgString = "'@RG\\tID:0\\tSM:" + sampleID

    if @libraryName != nil && !@libraryName.empty?()
      rgString = rgString + "\\tLB:" + @libraryName.to_s
    end

    # If PU field was already obtained from config params, use that. Build up a
    # dummy PU field if it was not already available.
    if @rgPUField != nil && !@rgPUField.empty?()
       rgString = rgString + "\\tPU:" + @rgPUField.to_s
    else
      if @fcBarcode != nil && !@fcBarcode.empty?()
         rgString = rgString + "\\tPU:" + @fcBarcode.to_s
      end
    end

    rgString = rgString + "\\tCN:BCM\\tDT:" + currentTime.strftime("%Y-%m-%dT%H:%M:%S%z")
    rgString = rgString + "\\tPL:Illumina"
    rgString = rgString + "'"
    puts "RGString = " + rgString.to_s
    return rgString.to_s
  end

  # Run the script to sort a bam, mark dups, fix mate info, fix CIGAR and
  # calculate mapping stats etc
  def buildBAMProcessingCmd()
    cmd = "ruby " + File.dirname(__FILE__) + "/BAMProcessor.rb " + @fcBarcode.to_s + 
          " " + @isFragment.to_s + " " + @filterPhix.to_s + " " + @samFileName + 
          " " + @sortedBam + " " + @markedBam
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
    objPostRun = Scheduler.new(@fcBarcode + "_post_run", postRunCmd)
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
  @cpuCores      = 8     # Processor cores
  @priority      = "normal" # Execution priority
  @helper        = nil   # PipelineHelper instance
  @fcName        = ""    # Flowcell name
end 


# Instantiate the BWA_BAM class while specifying the reference fasta file as the
# parameter
obj = BWA_BAM.new()
obj.process()
