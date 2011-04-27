#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "third_party")
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "bin")
$:.unshift File.dirname(__FILE__)

require 'fileutils'
require 'PipelineHelper'
require 'Scheduler'

# Class to create SampleSheet.csv in the basecalls directory
# and split the reads into directory bins based on the barcodes
class QseqSplitter
  def initialize(flowcellName)
    initializeDefaultValues()
    @fcName = flowcellName
    @priority = "high" # Scheduling priority - normal or high

    getLaneBarcodes()
    puts "Found the following lane barcodes : "
    puts "Total barcodes = " + @laneBarcodes.length.to_s

    puts "List of barcodes found"
    @laneBarcodes.each do |bc|
      puts bc.to_s 
    end

    # If the flowcell is multiplexed, write SampleSheet to basecalls directory
    # and create the output directory bins under bascalls/Demultiplexed using
    # Illumina CASAVA's demultiplexer
    if flowcellMultiplexed?()
      @baseCallsDir = @pHelper.findBaseCallsDir(@fcName)

      if @baseCallsDir == nil || @baseCallsDir.empty?()
        puts "ERROR : Did not find basecalls directory for FC : " + @fcName
        exit -1
      end

      @outputDir = @baseCallsDir + "/Demultiplexed"
 
      writeSampleSheet()
      createDirectoryBins()
      runMake()
      startLaneAnalysisBarcodeFC()
    else
      # The flowcell is not multiplexed. Start the analysis. 
      puts "Starting GERALD analysis"
      startLaneAnalysis()
    end
  end

  private
    def initializeDefaultValues()
      @fcName       = nil                   # Flowcell name
      @pHelper      = PipelineHelper.new()  # Instantiate PipelineHelper
      casavaPath    = "/stornext/snfs5/next-gen/Illumina/" +
                      "GAPipeline/CASAVA1_7/CASAVA-1.7.0-Install/bin"
      @demuxScript  = casavaPath + "/demultiplex.pl"
      @laneBarcodes = Array.new
      @baseCallsDir = nil
      @outputDir    = nil
    end

    # Read lane barcodes from a text file right now. When LIMS script is
    # available, retrieve them from LIMS
    def readLaneBarcodes(laneBarcodeFile)
      lines = IO.readlines(laneBarcodeFile)

      lines.each do |line|
        @laneBarcodes << line.strip
      end 
    end

    # Obtain the lane barcode for the flowcell from LIMS
    def getLaneBarcodes()
      limsScript = "/stornext/snfs5/next-gen/Illumina/ipipe/third_party/" +
                   "getFlowCellInfo.pl"

      limsQueryCmd = "perl " + limsScript + " " + extractFCNameForLIMS(@fcName)
      puts "Querying LIMS to obtain lane barcodes. Command : " + limsQueryCmd

      output = `#{limsQueryCmd}`

      if output.match(/[Ee]rror/)
        puts "ERROR in obtaining lane barcode information. Message : " + output 
        exit -1
      end

      # LIMS did not report any errors, proceed to parse the barcodes
      lines = output.split("\n")

      lines.each do |line|

        if(line.match(/-[1-8]$/))
          laneBC = line.slice(/[1-8]$/)
          @laneBarcodes << laneBC.to_s
        elsif line.match(/-[1-8]-ID[01][0-9]$/)
          laneBC = line.slice(/[1-8]-ID[01][0-9]$/)
          @laneBarcodes << laneBC.to_s
        elsif line.match(/-[1-8]-IDMB\d$/)
          laneBC = line.slice(/[1-8]-IDMB\d$/)
          @laneBarcodes << laneBC.to_s
        elsif line.match(/-[1-8]-IDMB\d\d$/)
          laneBC = line.slice(/[1-8]-IDMB\d\d$/)
          @laneBarcodes << laneBC.to_s
        end
      end
    end

    # Method to determine if the flowcell has multiplexed lanes
    # A flowcell is multiplexed if at least one lane has a barcode.
    # If a lane has a barcode, it would have the format x-IDYY, where
    # x is the lane number, YY is the corresponding barcode (ranging from
    # 01 to 12
    def flowcellMultiplexed?()

      @laneBarcodes.each do |laneBC|
        if laneBC.to_s.match(/[1-8]-ID[01]\d/)
          return true
        elsif laneBC.to_s.match(/[1-8]-IDMB/)
          return true
        end
      end
        return false
    end

    # Method to write a SampleSheet.csv in the basecalls directory of the
    # flowcell as part of the CASAVA step for splitting the reads
    def writeSampleSheet()
      puts "Writing SampleSheet.csv"
      fileName = @baseCallsDir + "/SampleSheet.csv" 
      file = File.new(fileName, "w")

      if file
        # Write to the file
        @laneBarcodes.each do |laneBC|
          if laneBC.to_s.match(/[1-8]-ID/)
            puts laneBC.to_s
            puts "Writing sample sheet for : " + laneBC.to_s
            laneNum = laneBC.gsub(/-ID.+/, "")
            bcTag   = laneBC.gsub(/^[1-8]-/, "")
            puts "Barcode tag = " + bcTag.to_s
            tagSequence = @pHelper.findBarcodeSequence(bcTag)
            line = @fcName + "," + laneNum.to_s + ",dummy_library,dummy_sample," +
                   tagSequence.to_s + "," + bcTag.to_s + ",n,r1,fiona\r\n"
            file.syswrite(line)
         end
        end    
        file.close()
        puts "Finished writing SampleSheet.csv"
      else
        puts "Error in creating SampleSheet.csv in " + @baseCallsDir.to_s
        exit -1
      end
    end

=begin
    # Helper method to reduce full flowcell name to FC name used in LIMS
    def extractFCNameForLIMS(fc)
      flowCellName = nil
      temp = fc.slice(/FC(.+)$/)
      if temp == nil
        flowCellName = fc.slice(/([a-zA-Z0-9]+)$/)
      else
        flowCellName = temp.slice(2, temp.size)
      end
      # With HiSeqs, a flowcell would have a prefix letter "A" or "B".
      # We remove that letter from the flowcell name since the flowcell
      # is not entered with that prefix in LIMS.
      # For GA2, this does not have any effect.
      flowCellName.slice!(/^[a-zA-Z]/)
      return flowCellName
    end
=end

  # Helper method to reduce full flowcell name to FC name used in LIMS
  def extractFCNameForLIMS(fc)
    return @pHelper.formatFlowcellNameForLIMS(fc)
  end

    # Method to run Illumina's demultiplex tool and create different directory
    # bins based on the tags specified in SampleSheet.csv
    # Can be improved - especially the error detection/handling part
    def createDirectoryBins()
      puts "Creating directory bins"
      cmd = @demuxScript + " --input-dir " + @baseCallsDir + 
            " --output-dir " + @outputDir  +
            " --sample-sheet " + @baseCallsDir + "/SampleSheet.csv" +
            " --mismatches 1 --correct-errors" 

     puts "Executing command " + cmd
     output = `#{cmd}`
     puts output

     if File::directory?(@outputDir)
       puts "Demultiplexed directory successfully created"
     else
       puts "ERROR : \"Demultiplexed\" directory was not created in " + @baseCallsDir
       exit -1
     end

     if File::exist?(@outputDir + "/SamplesDirectories.csv")
       puts "Demultiplexed directory also contains SamplesDirectories.csv"
     else
       puts "ERROR : \"Demultiplexed\" direcory does not contain \"SamplesDirectories.csv\""
       exit -1
     end
    end

  # Method to run "make" command on the cluster
  def runMake()
    puts "Running make command to split the Qseq files"
    currDir = Dir.pwd
    puts "Changing to output directory : " + @outputDir.to_s
    Dir.chdir(@outputDir)
    s = Scheduler.new(@fcName + "_split_Qseq", "make -j7")
    s.setMemory(28000)
    s.setNodeCores(7)
    s.setPriority(@priority)
    s.runCommand()
    @makeJobID = s.getJobID()
    puts "FOUND JOB ID = " + @makeJobID.to_s
    @makeJobName = s.getJobName()
    puts "FOUND JOB NAME = " + @makeJobName
    Dir.chdir(currDir)
  end

  # Start individual lane analysis
  def startLaneAnalysis()
    cmdPrefix = "ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/BWA_Pipeline.rb " +
                @fcName.to_s 

    @laneBarcodes.each do |laneBarcode|
      cmd = cmdPrefix + " " + laneBarcode.to_s 
      puts "Running the command : " + cmd.to_s
      output = `#{cmd}`
   end
  end

    # Start analysis for a multiplexed flowcell
  def startLaneAnalysisBarcodeFC()
 
    if @makeJobName == nil || @makeJobName.empty?()
      puts "ERROR : name of make job is null or empty"
      exit -1
    end

    cmdPrefix = "ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/BWA_Pipeline.rb " +
                @fcName.to_s

    @laneBarcodes.each do |laneBarcode|
      cmd = cmdPrefix + " " + laneBarcode.to_s
      obj = Scheduler.new(@fcName + "-" + laneBarcode.to_s, cmd)
      obj.setMemory(8000)
      obj.setNodeCores(1)
      obj.setPriority(@priority)
      obj.setDependency(@makeJobName.to_s)
      obj.runCommand()
      jobName = obj.getJobName()
      puts "Job for command : " + cmd + " : " + jobName.to_s
   end
 end
end

flowcell = ARGV[0]

obj = QseqSplitter.new(ARGV[0])
