#!/usr/bin/ruby

require 'fileutils'

# Script to filter phix reads from the export and sequence files
class PhixFilter
  def initialize()
      if false == shouldFilterPhixReads()
        puts "Marker file that indicates reads are spiked is absent. Hence, exiting..."
        exit 0
      end
    begin
      exportFileList = Dir["*export*"]

      puts exportFileList

      if exportFileList == nil || exportFileList.length == 0
        puts "No export files found in " + Dir.pwd + ". Exiting..."
        exit 0
      else
       numExportFiles = exportFileList.length
       puts "Found " + numExportFiles.to_s + " export files"

       if numExportFiles == 1
         filterPhixReads(exportFileList[0], "")
       else
         filterPhixReads(exportFileList[0], exportFileList[1])
       end
    end
    rescue Exception => e 
     puts e.message
     puts e.backtrace.inspect
     handleError() 
    end
  end

private
  # Method that checks if phix reads should be filtered from the current lane.
  # It returns true if those reads should be removed, else returns false
  def shouldFilterPhixReads()
    # If the BaseCalls directory contains an empty marker file "filterphix"
    # return true else return false
    geraldDir = FileUtils.pwd
    baseCallsDir = geraldDir.gsub(/BaseCalls.+$/, "") + "BaseCalls" 
    if File::exist?(baseCallsDir + "/filterphix")
      return true
    else
     return false
    end
  end

  def handleError()
   puts "OOPS error occurred, need to do something"
   exit -1 
  end
    
  # Method to find sequence file corresponding to export file. Not used
  # now.
  def findSequenceFile(exportFile)
    sequenceFile = exportFile.gsub("export", "sequence")

    if !File::exist?(sequenceFile) || !File::readable?(sequenceFile)
      raise "Sequence File : " + sequenceFile + " cannot be read"
    end
    return sequenceFile
  end

  # Method to build proper command line parameters for the java utiliy that 
  # filters Phix mapping reads from the sequence files. For paired end, specify
  # two export files (for read1 and read2). For fragment run, specify value for 
  # exportFile1 and leave exportFile2 empty
  def filterPhixReads(exportFile1, exportFile2)
    if exportFile1 == nil || exportFile1.empty?
      raise "Null or empty value provided for export file 1"
    end

    jarName = "/stornext/snfs5/next-gen/Illumina/ipipe/java/FilterPhixReads.jar"
    cmd = "java -Xmx8G -jar " + jarName + " " + exportFile1

    if exportFile2 != nil && !exportFile2.empty?
      cmd = cmd + " " + exportFile2
    end
    puts "Executing command : " + cmd
    output = `#{cmd}`
    returnCode = $?

    puts "Output from the program"
    puts output
 
    if returnCode == 0
      puts "Completed successfully..."
    else
     puts "Error in filtering phix reads. Return code : " + returnCode.to_s
     #TODO: handle error in this case too
    end
  end
end

obj = PhixFilter.new
