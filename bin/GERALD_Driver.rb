#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'fileutils'
require 'FCInfo.rb'
require 'BuildGERALDConfig.rb'
require 'BuildGERALDCommand.rb'
require 'Scheduler'
require 'PipelineHelper'

#Driver script to start GERALD analysis for specified lane of FC
class GERALD_Driver
  def initialize(args)
    if args.length != 2 && args.length != 5
      printUsage()
    else
      @fcName        = args[0]
      @laneNum       = args[1]
      @numCycles     = 0
      @fcPaired      = false
      @referencePath = ""

      if args.length == 5
        @numCycles  = Integer(args[2])
        if args[3].downcase.eql?("paired")
          @fcPaired = true
        else
          @fcPaired = false
        end
        @referencePath = args[4]
      end

      puts "Flowcell Name   : " + @fcName
      puts "Lane to analyze : " + @laneNum
      createWorkingDirectory()
      createGERALDConfig()
      createGERALDCommand()
      createGERALDDirectory()
      runGERALDMakefile()
    end
  end

  private
    def printUsage()
      puts "Usage:"
      puts "\r\nScenario 1, Obtaining information from LIMS"
      puts "  ruby " + __FILE__ + " FlowCell LaneNumbers"
      puts "\r\nScenario 2, Providing flowcell info on command line"
      puts "  ruby " + __FILE__ + " FlowCell LaneNumbers NumCycles FCType " +
           "ReferencePath"
      puts "    FCType    - Specify paired if FC is paired, otherwise fragment"
      puts ""
      exit -1
    end

    # Helper method to create a working directory. The config file
    # and the GERALD command file are copied there.
    def createWorkingDirectory()
      rootPath = "/stornext/snfs5/next-gen/Illumina/goats"
      @workingDir = ""

      time = Time.new

      @workingDir = rootPath + "/" + time.strftime("%Y/%m/%d") +
                   "/" + @fcName + "-L" + @laneNum.to_s
      puts @workingDir.to_s
      FileUtils.mkdir_p(@workingDir)
    end

    # Helper method to pull information from LIMS and build GERALD
    # configuration file
    def createGERALDConfig()
      begin
        # Determine the actual sequencer type by looking at
        # complete fc name (variable fcName)
        if @fcName.match("EAS034") || @fcName.match("EAS376")
          seqType = "ga2"
        else
          seqType = "hiseq"
        end

        # Since the user did not specify reference path, num cycles
        # and paired / fragment info, we obtain this info from LIMS
        if @numCycles == 0 || @referencePath.eql?("")

          puts "\r\nContacting LIMS to get flowcell information"

          fcInfo     = FCInfo.new(@fcName)
          @fcPaired  = fcInfo.paired?()
          @numCycles = fcInfo.getNumCycles()

          # If multiple lanes are specified for analysis, ensure that the
          # reference paths for all these lanes are equal. If yes, then set
          # the member variable @referencePath and continue.
          # Otherwise, throw the exception and abort.
          if @laneNum.length > 1
            puts "Number of Lanes to Analyze : " + @laneNum.length.to_s
            tempRefArray = Array.new
            
            @laneNum.each_byte do |lane|
              tempRefArray << fcInfo.getRefPath(lane.chr.to_s)
            end
            tempRefArray.uniq!

            if tempRefArray.length > 1
              raise "Specified Lanes have different references"
            elsif tempRefArray.length == 1
              @referencePath = tempRefArray[0]
            end
          # If single lane is specified for analysis, get its reference path  
          else
            @referencePath   = fcInfo.getRefPath(@laneNum)
          end
          
          if false == fcInfo.refPathValid?(@laneNum[0].chr.to_s)
            errMsg = "Reference Path " + @referencePath + " is invalid"
            handleErrorAndAbort(errMsg)
          end
        end

        puts "\r\nNumber of Cycles : " + @numCycles.to_s
        
        if @fcPaired == true
          puts "Flowcell is paired-end"
        else
          puts "Flowcell is fragment"
        end

        puts "Reference Path : " + @referencePath

        # All is valid so far. Continue to generate GERALD config file
        puts "\r\nWriting GERALD file config.txt in " + @workingDir
        geraldConfig = BuildGERALDConfig.new(@laneNum, @referencePath, @numCycles,
                                             @fcPaired, @workingDir + "/config.txt", 
                                             seqType)
        geraldConfig.buildConfigFile()
        puts "Completed..."
      rescue Exception => e
        handleErrorAndAbort(e.message)
        # puts e.backtrace.inspect
      end
    end

    # Helper method to create GERALD command file
    def createGERALDCommand()
      begin
        puts "\r\nWriting generate_makefiles.sh in " + @workingDir
        FileUtils.chdir(@workingDir)
        geraldCmd = BuildGERALDCommand.new(@fcName)
        puts "Completed..."
      rescue Exception => e
        # puts e.backtrace.inspect
        handleErrorAndAbort(e.message)
      end
    end

    # Helper method to create GERALD directory under 
    # flowcell/Data/Intensities/Basecalls and then create a softlink
    # "gerald_dir" to the GERALD directory
    def createGERALDDirectory()
      # Run the GERALD command to build GERALD output directory

      puts "\r\nCreating GERALD directory"
      `sh generate_makefiles.sh`

      file = File.open("generate_makefiles.sh.log", "r")
      output = file.read()

      geraldDir = output.slice(/Output folder\s+\S+/)

      if geraldDir == nil || geraldDir.eql?("")
        errMsg = "Error : Did not get information about GERALD directory " +
                 "Output from running GERALD command : " + output.to_s
        handleErrorAndAbort(errMsg)
      else
        geraldDir.gsub!(/Output folder\s+/, '')

        # Since path to GERALD directory was shown in the output, perform
        # further checks to ensure that the directory actually exists, and
        # the Illumina self-tests for the gerald directory pass.

        selfTestVerificationText = "Run \'make self_test\' on " + geraldDir +
                                   " completed with no problems"
        
        if !output.match(selfTestVerificationText) || !File::exist?(geraldDir)
          errMsg = "Error: GERALD Directory " + geraldDir + " does not exist or" +
                   " Illumina make self test failed"
          handleErrorAndAbort(errMsg)
        else
          FileUtils.ln_s(geraldDir, "gerald_dir")
          puts "Finished creating GERALD directory at "
          puts geraldDir.to_s
        end
      end
    end

    # Helper method to run the GERALD makefile
    def runGERALDMakefile()
      puts "\r\nRunning GERALD Make targets"
      FileUtils.cd("gerald_dir")

      pHelper = PipelineHelper.new
      baseCallsDir = pHelper.findBaseCallsDir(@fcName)
      parentJob = nil

      if File::exist?(baseCallsDir + "/bclToQseqJobName")
        lines = IO.readlines(baseCallsDir + "/bclToQseqJobName")
        parentJob = lines[0].strip
      end

      # Each host on cluster has 8 cores.
      numCores    = 8

      makeCmd = "make -j" + numCores.to_s + " all"
      scheduler = Scheduler.new(@fcName + "_" + @laneNum, makeCmd)
      scheduler.setMemory(28000)
      scheduler.setNodeCores(numCores)
      scheduler.setPriority("high")
      
      if parentJob != nil
        scheduler.setDependency(parentJob)
      end

      scheduler.runCommand()
    end

    def handleErrorAndAbort(msg)
      puts "Error encountered. Message : \r\n" + msg
      puts "Aborting execution\r\n"
      exit -4
    end

    @fcName        = ""    # Flowcell name
    @laneNum       = ""    # Lanes to analyze
    @referencePath = ""    # Reference path
    @numCycles     = 0     # Num. cycles per read
    @fcPaired      = false # If true, paired FC, else fragment
    @workingDir    = ""    # Working dir of analysis
end

obj = GERALD_Driver.new(ARGV)
