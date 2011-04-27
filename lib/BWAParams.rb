#!/usr/bin/ruby

# Class representing parameters to be passed to BWA
class BWAParams
  def initialize
    @referencePath = nil      # BWA Reference Path
    @libraryName   = nil      # Library name of Sample
    @filterPhix    = false    # Don't filter phix reads
    @chipDesign    = nil      # Name of chip design
    @sampleName    = nil      # Sample name
    @schedulingQ   = "normal" # Scheduler queue to use - high, normal
    @rgPUField     = nil      # PU field of RG tag (rundate_machine-name_FCbarcode)
    @fcBarcode     = nil      # Flowcell barcode

    # Name of config file
    @configFile = "BWAConfigParams.txt"
  end

  def getReferencePath()
    return @referencePath
  end

  def getLibraryName()
    return @libraryName
  end

  def getSampleName()
    return @sampleName
  end

  def filterPhix?()
    return @filterPhix
  end

  def getChipDesignName()
    return @chipDesign
  end

  def getSchedulingQueue()
    return @schedulingQ
  end

  def getRGPUField()
    return @rgPUField
  end

  def getFCBarcode()
    return @fcBarcode.to_s
  end

  def setReferencePath(value)
    @referencePath = value
  end

  def setLibraryName(value)
    @libraryName = value
  end

  def setSampleName(value)
    @sampleName = value
  end

  def setPhixFilter(value)
    if value == true
      @filterPhix = true
    else
      @filterPhix = false
    end
  end

  def setChipDesignName(value)
    @chipDesign = value
  end

  def setschedulingQ(value)
    if value.eql?("high")
      @schedulingQ = "high"
    end
  end

  def setRGPUField(value)
    @rgPUField = value
  end

  def setFCBarcode(value)
    @fcBarcode = value
  end

  # Write the config parameters to a file
  def toFile(destDir)
    fileHandle = File.new(destDir + "/" + @configFile, "w")

    if !fileHandle
      raise "Error : Could not open " + @configFile + " to write"
    end

    if @referencePath != nil && !@referencePath.empty?()
      fileHandle.puts("REFERENCE_PATH=" + @referencePath)
    else
      fileHandle.puts("REFERENCE_PATH=")
    end

    if @libraryName != nil && !@libraryName.empty?()
      fileHandle.puts("LIBRARY_NAME=" + @libraryName)
    else
      fileHandle.puts("LIBRARY_NAME=")
    end

    if @sampleName != nil && !@sampleName.empty?()
      fileHandle.puts("SAMPLE_NAME=" + @sampleName.to_s)
    end
    
    fileHandle.puts("FILTER_PHIX=" + @filterPhix.to_s)

    if @chipDesign != nil && !@chipDesign.empty?()
      fileHandle.puts("CHIP_DESIGN=" + @chipDesign.to_s)
    end

    if @rgPUField != nil && !@rgPUField.empty?()
      fileHandle.puts("RG_PU_FIELD=" + @rgPUField.to_s)
    end

    if @fcBarcode != nil && !@fcBarcode.empty?()
      fileHandle.puts("FC_BARCODE=" + @fcBarcode.to_s)
    end

    if @schedulingQ != nil && !@schedulingQ.empty?()
      fileHandle.puts("SCHEDULER_QUEUE=" + @schedulingQ.to_s)
    end

    fileHandle.close()
  end

  def loadFromFile()
    @filterPhix    = false
    @libraryName   = nil
    @referencePath = nil
    @chipDesign    = nil
    @sampleName    = nil
    @schedulingQ   = "normal"
    @rgPUField     = nil
    @fcBarcode     = nil

    if File::exist?(@configFile)
      lines = IO.readlines(@configFile)

      lines.each do |line|
        if line.match(/LIBRARY_NAME=\S+/)
          @libraryName = line.gsub(/LIBRARY_NAME=/, "")
          @libraryName.strip!
        elsif line.match(/SAMPLE_NAME=\S+/)
          @sampleName = line.gsub(/SAMPLE_NAME=/, "")
          @sampleName.strip!
        elsif line.match(/REFERENCE_PATH=\S+/)
          @referencePath = line.gsub(/REFERENCE_PATH=/, "")
          @referencePath.strip!
        elsif line.match(/FILTER_PHIX=true/)
          @filterPhix = true
        elsif line.match(/CHIP_DESIGN=\S+/)
          @chipDesign = line.gsub(/CHIP_DESIGN=/, "")
          @chipDesign.strip!
        elsif line.match(/SCHEDULER_QUEUE=\S+/)
          @schedulingQ = line.gsub(/SCHEDULER_QUEUE=/, "")
          @schedulingQ.strip!
        elsif line.match(/RG_PU_FIELD=\S+/)
          @rgPUField = line.gsub(/RG_PU_FIELD=/, "")
          @rgPUField.strip!
        elsif line.match(/FC_BARCODE=\S+/)
          @fcBarcode = line.gsub(/FC_BARCODE=/, "")
          @fcBarcode.strip!
        end
      end
    end
  end
end
__END__

obj = BWAParams.new()
#=begin
obj.setLibraryName("foofoo")
obj.setReferencePath("/sdf/sdf/sdf/sdf/sdf/sdf.fa")
obj.setPhixFilter(true)
obj.setFCBarcode("mybarcode")
obj.toFile(".")
#=end
obj.loadFromFile()
lib = obj.getLibraryName()
if lib != nil && !lib.empty?()
  puts "lib = " + lib.to_s
else
  puts "lib is null"
end
path = obj.getReferencePath()
if path == nil || path.empty?()
puts "Ref is null"
else
puts "Ref = " + path.to_s
end
puts "Phix_filter = " + obj.filterPhix?().to_s
puts "FC Barcode = " + obj.getFCBarcode().to_s
