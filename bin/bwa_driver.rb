#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

# Class to read the referenceFile from the GERALD directory
# and execute the bwa_bam.rb script to start alignment using BWA.
class BWA_Driver

  def initialize()
    begin
      @referenceFile = "referencePath"
      @bwaScriptPath    = File.dirname(__FILE__) + "/bwa_bam.rb"             
      @limsUploadScript = File.dirname(__FILE__) + "/upload_LIMS_results.rb"

      lines = IO.readlines("./" + @referenceFile)

      if lines == nil || lines.size < 1
        raise "Error. Could not obtain BWA reference path"
      end

      bwaReference = lines[0].strip
      puts "Found BWA Reference Path : " + bwaReference.to_s

      if bwaReference.casecmp("sequence") != 0
        bwaCmd = "ruby " + @bwaScriptPath + " " + bwaReference.to_s
        output = `#{bwaCmd}`
        puts output.to_s
      else
        puts "Alignment is not desired. Upload results to LIMS and exit"
        uploadResCmd = "ruby " + @limsUploadScript
        puts "Command to upload results to LIMS : " + uploadResCmd.to_s
        output = `#{uploadResCmd}`
        puts output.to_s
      end
    rescue Exception => e
      puts e.message
    end
  end
 
  private
    @referenceFile = "" # Name of the reference file to open
    @bwaScriptPath = ""             
end

obj = BWA_Driver.new()
