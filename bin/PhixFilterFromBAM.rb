#!/usr/bin/ruby

require 'fileutils'

# Script to filter phix reads from the export and sequence files
class PhixFilterFromBAM
  def initialize(bamName)
      if false == shouldFilterPhixReads()
        puts "Marker file that indicates reads are spiked is absent. Hence, exiting..."
        exit 0
      end
    begin
      bamFile = bamName

      if bamFile == nil || bamFile.eql?("") || !File::exist?(bamFile)
        puts "Invalid File name specified, or missing file " + Dir.pwd + ". Exiting..."
        exit 0
      else
       puts "Filtering BAM File : " + bamFile.to_s

       filterPhixReads(bamFile)
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

  # Method to build proper command line parameters for the java utiliy that 
  # filters Phix mapping reads from the sequence files. For paired end, specify
  # two export files (for read1 and read2). For fragment run, specify value for 
  # exportFile1 and leave exportFile2 empty
  def filterPhixReads(bamFile)

    #TODO : Remove the hardcoded path
    jarName = "/stornext/snfs5/next-gen/Illumina/ipipe/java/PhixFilterFromBAM.jar"
    cmd = "java -Xmx8G -jar " + jarName + " I=" + bamFile + " 1>phixfilter.out 2>phixfilter.err"

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

bamFile = ARGV[0]
obj = PhixFilterFromBAM.new(bamFile)
