#!/usr/bin/ruby
# Class to encapsulate creation of GERALD configuration file

class BuildGERALDConfig
  def initialize(lanes, refPath, numCycles, isPaired, output, seqType, mapAlgo)
    @lanesToAnalyze = lanes
    @referencePath  = refPath
    @numCycles      = numCycles
    @paired         = isPaired
    @fcVersion      = "v4" # hardcode to version 4 FC for now
    @outputFileName = output
    @seqType        = seqType.downcase
    @mappingAlgo    = mapAlgo.downcase # Mapper to use - bwa or eland

    if !@mappingAlgo.eql?("eland") && !@mappingAlgo.eql?("bwa")
      raise "Invalid mapping algorithm specified : " + @mappingAlgo
    end

    if !@seqType.eql?("ga2") && !@seqType.eql?("hiseq")
      raise "Invalid sequencer type specified : " + @seqType
    end

    initializeDefaultParameters()
  end

  # Public method to build GERALD config file
  def buildConfigFile()

    fileHandle = File.new(@outputFileName, "w")

    if fileHandle == nil
      puts "UNABLE TO CREATE FILE : " + @outputFileName.to_s
      raise "Error in creating config file : " + @outputFileName.to_s
    end

    if !@referencePath.match(/[Ss]equence/)
      fileHandle.write("ELAND_GENOME " + @referencePath + "\n")
    end
    writeAnalysisLines(fileHandle)
    fileHandle.write("USE_BASES Y"   + @numCycles.to_s   + "\n")
    fileHandle.write("FLOW_CELL "    + @fcVersion.to_s   + "\n")
    fileHandle.write("WITH_SEQUENCE true\n")

    # As of June 1, 2010
    # we set ELAND_SET_SIZE to 4 for HiSeq analysis based on emails
    # with Illumina.
    # For GA2, we set it to 24 which implies 10 concurrent eland 
    # processes for paired end runs.
    if @seqType.eql?("hiseq")
      fileHandle.write("ELAND_SET_SIZE 4\n")
    else
      fileHandle.write("ELAND_SET_SIZE 30\n")
    end

    fileHandle.write("WEB_DIR_ROOT " + @webDirRoot.to_s  + "\n")
    fileHandle.write("EMAIL_SERVER " + @emailServer.to_s + "\n")
    fileHandle.write("EMAIL_DOMAIN " + @emailDomain.to_s + "\n")
    fileHandle.write("EMAIL_LIST "   + @emailList.to_s   + "\n")

    if !@postRunCommand.eql?("")
      fileHandle.write("POST_RUN_COMMAND " + @postRunCommand.to_s + "\n")
    end
    fileHandle.close
  end

  private

  # Helper method to write "ANALYSIS" lines in GERALD configuration
    def writeAnalysisLines(fileHandle)
      algorithm = ""
      lanesNotAnalyzed = ""

      if @referencePath.match(/[Ss]equence/)
        @paired == true ? algorithm = "sequence_pair" :
                          algorithm = "sequence"
      else
        @paired == true ? algorithm = "eland_pair" :
                          algorithm = "eland_extended"
      end
      fileHandle.write(@lanesToAnalyze.to_s + ":ANALYSIS " + algorithm + "\n")

      for i in 1..8
        if !@lanesToAnalyze.match(i.to_s)
          lanesNotAnalyzed = lanesNotAnalyzed.to_s + i.to_s
        end
      end
      if !lanesNotAnalyzed.eql?("")
        fileHandle.write(lanesNotAnalyzed.to_s + ":ANALYSIS none\n")
      end
    end

    # Helper method initialize default parameters whose values
    # don't change per run
    def initializeDefaultParameters()
      @webDirRoot     = "file:///stornext/snfs5"
      @emailServer    = "mail.hgsc.bcm.tmc.edu"
      @emailDomain    = "bcm.edu"
      @emailList      = "niravs@bcm.edu dc12@bcm.edu"

      # Select the appropriate post run based on whether mapping is to be
      # done using Eland or BWA
      if @mappingAlgo.eql?("eland")
         @postRunCommand = "/stornext/snfs5/next-gen/Illumina/ipipe/" +
                           "bin/postrun_eland.sh" 
      else
         @postRunCommand = "ruby /stornext/snfs5/next-gen/Illumina/ipipe/" +
                           "bin/postrun.rb" 
      end
    end

    # Member variables of the class
    @lanesToAnalyze = ""   # Lane numbers to analyze
    @referencePath  = ""   # Path to reference
    @paired         = true # Whether FC is paired or fragment
    @numCycles      = 0    # Value for USE_BASES in config file
    @fcVersion      = "v4" # Value for FLOW_CELL in config file
    @outputFileName = ""   # File name to write GERALD configuration to
    @webDirRoot     = ""   # Value for WEB_DIR_ROOT
    @emailServer    = ""   # Value for EMAIL_SERVER
    @emailDomain    = ""   # Value for EMAIL_DOMAIN
    @emailList      = ""   # Value for EMAIL_LIST
    @postRunCommand = ""   # Value for POST_RUN_COMMAND
end

#obj = BuildGERALDConfig.new("58", "/data/slx/references/p/phix/squash", 95, false, "config.txt")
#obj.buildConfigFile()
