#!/usr/bin/ruby

require 'fileutils'
require 'PipelineHelper'
require 'Scheduler'

# Class to create SampleSheet.csv in the basecalls directory
# and split the reads into directory bins based on the barcodes
class QseqSplitter
  def initialize(flowcellName, laneBarcodeFile)
    initializeDefaultValues()
    @fcName = flowcellName

    readLaneBarcodes(laneBarcodeFile)
    if false == flowcellMultiplexed?()
      return
    end
    @baseCallsDir = @pHelper.findBaseCallsDir(@fcName)

    if @baseCallsDir == nil || @baseCallsDir.empty?()
      puts "ERROR : Did not find basecalls directory for FC : " + @fcName
      exit -1
    end

    @outputDir = @baseCallsDir = "/Demultiplexed"
 
    writeSampleSheet()
    createDirectoryBins()
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

    # Method to determine if the flowcell has multiplexed lanes
    # A flowcell is multiplexed if at least one lane has a barcode.
    # If a lane has a barcode, it would have the format x-IDYY, where
    # x is the lane number, YY is the corresponding barcode (ranging from
    # 01 to 12
    def flowcellMultiplexed?()

      @laneBarcodes.each do |laneBC|
        if laneBC.to_s.match(/[1-8]-ID[01]\d/)
          return true
        end
      end
        return false
    end

    # Method to write a SampleSheet.csv in the basecalls directory of the
    # flowcell as part of the CASAVA step for splitting the reads
    def writeSampleSheet()
      fileName = @baseCallsDir + "/SampleSheet.csv" 
      file = File.new(fileName, "w")

      if file
        # Write to the file
        @laneBarcodes.each do |laneBC|
          if laneBC.to_s.match(/[1-8]-ID[01]\d/)
            puts laneBC.to_s
            laneNum = laneBC.gsub(/-ID\d\d/, "")
            bcTag   = laneBC.gsub(/^[1-8]-/, "")
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
    currDir = Dir.pwd
    dir.chdir(@outputDir)
    s = Scheduler.new(@fcName + "_split_Qseq", "make -j6")
    s.setMemory(28000)
    s.setNodeCores(6)
    s.setPriority("high")
    s.runCommand()
    @jobID = s.getJobID()
    puts "FOUND JOB ID = " + @jobID.to_s
    @jobName = s.getJobName()
    puts "FOUND JOB NAME = " + @jobName
    dir.chdir(currDir)
  end
end

flowcell        = ARGV[0]
laneBarcodeFile = ARGV[1]

obj = QseqSplitter.new(ARGV[0], ARGV[1])
