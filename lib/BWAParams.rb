#!/usr/bin/ruby

# Class representing parameters to be passed to BWA
class BWAParams
  def initialize
    @referencePath = nil    # BWA Reference Path
    @libraryName   = nil    # Library name of Sample
    @filterPhix    = false  # Don't filter phix reads
    @chipDesign    = nil    # Name of chip design

    # Name of config file
    @configFile = "BWAConfigParams.txt"
  end

  def getReferencePath()
    return @referencePath
  end

  def getLibraryName()
    return @libraryName
  end

  def filterPhix?()
    return @filterPhix
  end

  def getChipDesignName()
    return @chipDesign
  end

  def setReferencePath(value)
    @referencePath = value
  end

  def setLibraryName(value)
    @libraryName = value
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
    
    fileHandle.puts("FILTER_PHIX=" + @filterPhix.to_s)

    if @chipDesign != nil && !@chipDesign.empty?()
      fileHandle.puts("CHIP_DESIGN=" + @chipDesign.to_s)
    end

    fileHandle.close()
  end

  def loadFromFile()
    @filterPhix    = false
    @libraryName   = nil
    @referencePath = nil
    @chipDesign    = nil

    if File::exist?(@configFile)
      lines = IO.readlines(@configFile)

      lines.each do |line|
        if line.match(/LIBRARY_NAME=\S+/)
          @libraryName = line.gsub(/LIBRARY_NAME=/, "")
          @libraryName.strip!
        elsif line.match(/REFERENCE_PATH=\S+/)
          @referencePath = line.gsub(/REFERENCE_PATH=/, "")
          @referencePath.strip!
        elsif line.match(/FILTER_PHIX=true/)
          @filterPhix = true
        elsif line.match(/CHIP_DESIGN=\S+/)
          @chipDesign = line.gsub(/CHIP_DESIGN=/, "")
          @chipDesign.strip!
        end
      end
    end
  end
end
__END__

obj = BWAParams.new()
=begin
obj.setLibraryName("foofoo")
obj.setReferencePath("/sdf/sdf/sdf/sdf/sdf/sdf.fa")
obj.setPhixFilter(true)
obj.toFile()
=end
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