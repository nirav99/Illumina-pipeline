#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'fileutils'
require 'FCInfo.rb'
require 'BuildGERALDConfig.rb'
require 'BuildGERALDCommand.rb'
require 'Scheduler'
require 'PipelineHelper'
require 'BWAParams'
require 'EmailHelper'

class BWA_Pipeline
  def initialize(args)
    initializeDefaultParams()
    processCommandLineParameters(args)
    obtainInformationFromLIMS()
    createWorkingDirectory()
    createGERALDConfig()
    createGERALDCommand()
    createGERALDDirectory()
    runGERALDMakefile()
  end

private
  # Perform default initialization of class members
  def initializeDefaultParams()

    # Sequence event related members
    @fcName      = nil  # Name of the flowcell (Complete directory name)
    @limsFCName  = nil  # Name of flowcell to query LIMS
    @laneBarcode = nil  # Lane barcode
    @readLength  = 0    # Read length
    @fcPaired    = nil  # If true paired end else fragment
    @refPath     = nil  # Reference path
    @chipName    = nil  # Capture chip design name
    @sampleName  = nil  # Sample name
    @libraryName = nil  # Library name

    # Collaborating classes
    @bwaParams  = BWAParams.new      # To pass parameters to BWA
    @pHelper    = PipelineHelper.new # Instance of PipelineHelper

    # Scheduler related members
    @priority   = "normal"      # Priority of job, "normal" or "high"
  end

  # Parse command line parameters
  def processCommandLineParameters(args)
    if args.length != 5 && args.length != 2
      printUsage()
      exit -1
    else
      @fcName      = args[0]
      @laneBarcode = args[1]
      @limsFCName  = @pHelper.formatFlowcellNameForLIMS(@fcName)
    end

    if args.length == 5
      @readLength = Integer(args[2])
      
      if args[3].downcase.eql?("paired")
        @fcPaired = true
      else
        @fcPaired = false
      end
      @refPath = args[4]
    end
  end
  
  # Show usage information
  def printUsage()
    puts "Usage:"
    puts "\r\nScenario 1, Obtaining information from LIMS"
    puts "  ruby " + __FILE__ + " FlowCell LaneBarCode"
    puts "\r\nScenario 2, Providing flowcell info on command line"
    puts "  ruby " + __FILE__ + " FlowCell LaneBarCode NumCycles FCType " +
           "ReferencePath"
    puts "    FCType    - Specify paired if FC is paired, otherwise fragment"
    puts ""
  end

   # Obtain the information for specified flowcell-barcode from LIMS
  def obtainInformationFromLIMS()
    puts "Contacting LIMS to get information for " + @fcName.to_s + "-" + @laneBarcode.to_s
    begin
    fcInfo = FCInfo.new(@fcName.to_s, @laneBarcode.to_s)

    # For the next three parameters, get their values from LIMS only if the
    # user did not specify them at the command line.   
    if @readLength == 0
       @readLength = fcInfo.getNumCycles()
    end 

    if @fcPaired == nil
       @fcPaired = fcInfo.paired?()
    end

    if @refPath == nil
       @refPath = fcInfo.getRefPath()

       if @refPath == nil || @refPath.empty?()
          @refPath = "sequence"
       end
    end

    @chipName    = fcInfo.getChipDesignName() 
    @sampleName  = fcInfo.getSampleName()
    @libraryName = fcInfo.getLibraryName()
    rescue Exception => e
      puts e.message
      puts e.backtrace.inspect
    end
  end

  # Helper method to create a working directory. The config file
  # and the GERALD command file are copied there.
  def createWorkingDirectory()
    puts "Creating working directory"
    rootPath = "/stornext/snfs5/next-gen/Illumina/goats"
    @workingDir = ""

    time = Time.new

    @workingDir = rootPath + "/" + time.strftime("%Y/%m/%d") +
                 "/" + @fcName + "-L" + @laneBarcode.to_s
    puts @workingDir.to_s
    FileUtils.mkdir_p(@workingDir)
  end

  # Helper method to pull information from LIMS and build GERALD
  # configuration file
  def createGERALDConfig()
    puts "Creating GERALD configuration file"
    begin
      # Determine the actual sequencer type
      if @pHelper.isFCHiSeq(@fcName)
        seqType = "hiseq"
      else
        seqType = "ga2"
      end

      puts "\r\nRead Length : " + @readLength.to_s
        
      if @fcPaired == true
        puts "Flowcell is paired-end"
      else
        puts "Flowcell is fragment"
      end

      puts "Reference Path : " + @refPath

      # All is valid so far. Continue to generate GERALD config file
      puts "\r\nWriting GERALD file config.txt in " + @workingDir

      # Since alignment is going to be done by BWA, we fake the reference 
      # path in GERALD as "sequence". This will only generate Illumina
      # sequence files. BWA will be fired as post-run step.
      # In addition, specify the last parameter for GERALD configuration as
      # bwa to let BuildGERALDConfig know that bwa mapper will be used.
      laneNum = @laneBarcode.slice(0).chr.to_s
      geraldConfig = BuildGERALDConfig.new(laneNum, "sequence", @readLength,
                                           @fcPaired, @workingDir + "/config.txt", 
                                           seqType, "bwa")
      geraldConfig.buildConfigFile()
      puts "Completed..."
    rescue Exception => e
      puts e.backtrace.inspect
      handleErrorAndAbort(e.message)
    end
  end

  # Helper method to create GERALD command file
  def createGERALDCommand()
    begin
      puts "\r\nWriting generate_makefiles.sh in " + @workingDir
      FileUtils.chdir(@workingDir)
      geraldCmd = BuildGERALDCommand.new(@fcName, @laneBarcode)
      puts "Completed..."
    rescue Exception => e
      puts e.message
      puts e.backtrace.inspect
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
      writeBWAParamsToGeraldDir(geraldDir.to_s)
    end
  end
end

  # Helper method to populate the BWA config parameters object and write in
  # GERALD directory
  def writeBWAParamsToGeraldDir(geraldDir)
    puts "Writing BWA configration parameters in GERALD directory"

    # Note: This is a short-term workaround to set correct reference path for
    # TREN or TLVR libraries. If library name matches these, use hg19 reference or else use
    # the reference path provided. 
    if @libraryName != nil && !@libraryName.empty?() && 
       (@libraryName.match(/TREN/)  || @libraryName.match(/TLVR/))
      @bwaParams.setReferencePath("/stornext/snfs5/next-gen/Illumina/bwa_references/h/hg19/original/hg19.fa")
      puts "Setting reference path HG19 for BWA"
    else
      @bwaParams.setReferencePath(@refPath)
      puts "Setting BWA reference path : " + @refPath.to_s
    end

    begin
      puField = getPUField()

      if @sampleName != nil && !@sampleName.empty?()
        @bwaParams.setSampleName(@sampleName.to_s)
      else
        puts "Sample name is null or empty, not setting in BWAConfigParams"
      end

      if @libraryName != nil && !@libraryName.empty?()
        @bwaParams.setLibraryName(@libraryName)
      else
        puts "Library name is null or empty, not setting in BWAConfigParams"
      end

     @bwaParams.setRGPUField(puField)
     @bwaParams.setFCBarcode(@limsFCName + "-" + @laneBarcode.to_s)

     if @chipName != nil && !@chipName.empty?()
      # Note: This is a short-term workaround to set correct chip design when
      # library name contains TREN/TLVR and reference is hg19 until a permanent
      # solution is determined.
        if @libraryName.match(/TREN/)
          @bwaParams.setChipDesignName("/users/p-illumina/ezexome2_hg19")
          puts "Setting chip design name : /users/p-illumina/ezexome2_hg19" 
        elsif @libraryName.match(/TLVR/)
          @bwaParams.setChipDesignName("/users/p-illumina/vcrome2.1_hg19")
          puts "Setting chip design name : /users/p-illumina/vcrome2.1_hg19"
        else
          @bwaParams.setChipDesignName(@chipName.to_s)
          puts "Setting chip design name : " + @chipName.to_s
        end
      end
    rescue Exception => e
      puts e.message
      puts e.backtrace.inspect
    end

    # Nirav Shah on Feb 28, 2011 :
    # Hiseq flowcells are contaminated with 2% phix. We were contaminating reference
    # sequences with phix and then attempt to filter out phix reads from the BAM files.
    # It was decided on 25th Feb to stop removing phix since most of the data we generate
    # is humans. It might need to be re-enabled only if some project requires de-novo assembly.
    # In that case, uncomment the following lines, or set its value to true in BWAConfigParams.txt
=begin
    # Turn on Phix filtering for Hiseq FC that is not mapped to phix
    if @pHelper.isFCHiSeq(@fcName) == true && !@refPath.match("PhiX_plus_SNP.fa")
       @bwaParams.setPhixFilter(true)
    end
=end

    # Write the parameters to gerald directory
    @bwaParams.toFile(geraldDir)
  end

  # Method to obtain the PU (Platform Unit) field for the RG tag in BAMs. The
  # format is machine-name_yyyymmdd_FC_Barcode
  def getPUField()
     puField    = nil
     coreFCName = nil
     begin
       runDate    = "20" + @fcName.slice(/^\d+/)
       machName   = @fcName.gsub(/^\d+_/,"").slice(/[A-Za-z0-9-]+/).gsub(/SN/, "700")
       puts "Generating FCName for PU field"
       coreFCName = @pHelper.formatFlowcellNameForLIMS(@fcName) 
       puts "Core FC Name : "
       puts coreFCName.to_s
       puField    = machName.to_s + "_" + runDate.to_s + "_" + 
                    coreFCName.to_s + "-" + @laneBarcode.to_s
     rescue
       puField = machName.to_s + "_" + runDate.to_s + "_" +
                 @fcName.to_s + "_" + @laneBarcode.to_s 
     end
     return puField.to_s
  end

  # Helper method to run the GERALD makefile
  def runGERALDMakefile()
    puts "\r\nRunning GERALD Make targets"
    FileUtils.cd("gerald_dir")

    baseCallsDir = @pHelper.findBaseCallsDir(@fcName)
    parentJob = nil

   # Nirav Shah on April 15, 2011:
   # I have commented out this part because this script will be automatically
   # invoked from QseqSplitter.rb, which guarantees that qseq generation and
   # qseq demultiplexing (whenever applicable) has completed. This eliminates
   # the need to create the dependency on the qseq generation job.
=begin
    if File::exist?(baseCallsDir + "/bclToQseqJobName")
      lines = IO.readlines(baseCallsDir + "/bclToQseqJobName")
      parentJob = lines[0].strip
    end
=end

    # Each host on cluster has 8 cores.
    numCores    = 2

    makeCmd = "make -j" + numCores.to_s + " all"
    scheduler = Scheduler.new(@fcName + "_" + @laneBarcode, makeCmd)
    scheduler.setMemory(8000)
    scheduler.setNodeCores(numCores)
    scheduler.setPriority(@priority)
    
    if parentJob != nil
      scheduler.setDependency(parentJob)
    end
   
    scheduler.runCommand()
  end

  #TODO: Develop a better approach to handle errors
  def handleErrorAndAbort(msg)
    puts "Error encountered. Message : \r\n" + msg
    emailErrorMessage(msg)
    puts "Aborting execution\r\n"
    exit -4
  end

  # Send email describing the error message to interested watchers
  def emailErrorMessage(msg)
    obj          = EmailHelper.new()
    emailFrom    = "sol-pipe@bcm.edu"
    emailTo      = obj.getErrorRecepientEmailList()
    emailSubject = "Error in starting GERALD analysis for " + @fcName + "-" + @laneBarcode.to_s
    emailText    = msg

    obj.sendEmail(emailFrom, emailTo, emailSubject, emailText)
  end
end

obj = BWA_Pipeline.new(ARGV)
