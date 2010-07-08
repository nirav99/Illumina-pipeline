#!/usr/bin/env ruby

#This script prepares the "mini analysis" of a given flow cell.
#It creates a directory mini_analysis and copies over the Summary.htm
#Summary.htm, the plots, all sequence and eland_extended files
#to the mini_analysis directory

class MiniAnalysis
  def initialize()
    @currentDir = Dir.pwd 
    @miniDir    = @currentDir.gsub(/Data.*$/, 'mini_analysis') 
    @plotsDir   = @miniDir + "/Plots"

    puts "Current Directory : #@currentDir"
    puts "Mini-analysis Directory : #@miniDir"
    puts "Plots Directory : #@plotsDir"
    puts "Creating mini_analysis directory"  
    cmd = "mkdir -p " + @miniDir
    result = executeSystemCmd(cmd)
    cmd = "mkdir -p " + @plotsDir
    result = executeSystemCmd(cmd)
  end

  def executeSystemCmd(cmd)
    puts "Executing : " + cmd
    result = system(cmd)
    puts "Execution Result : " + result.to_s
    return result
  end

  def copyFiles()
    copySummaryFiles()
    copyPlots()
    copySequenceFiles()
    copyExportFiles()
#    copyElandExtendedFiles()
  end

  private 
  # Copy summary.htm and summary.xml files to mini_analysis directory
  # while renaming them using their lane numbers
  def copySummaryFiles()
    laneNumber = []
    configFileLines = IO.readlines("config.txt")
    idx=0
    while idx < configFileLines.size do
      if ( configFileLines[idx] =~ /^[1-8]+:ANALYSIS/) && !(configFileLines[idx] =~ /none/) then
        temp=configFileLines[idx].index(":") - 1
        lanesUsedForAnalysis = configFileLines[idx][0..temp]
        puts "Lane Number(s) = " + lanesUsedForAnalysis
      end
      idx += 1
    end
    system("cp Summary.htm #@miniDir/Summary_" + lanesUsedForAnalysis + ".htm")
    system("cp Summary.xml #@miniDir/Summary_" + lanesUsedForAnalysis + ".xml")
    system("cp config.txt #@miniDir/GeraldConfig_" + lanesUsedForAnalysis + ".txt")
  end

  def copyPlots()
    puts "Copying plots"
    system("cp ./Plots/*.* #@plotsDir")
  end  

  def copySequenceFiles()
    puts "Copying sequence files"
    listOfFiles = Dir["*sequence*"]
    listOfFiles.each { |file|
      copyUsingRsync(file)
    }
  end

  def copyElandExtendedFiles()
    puts "Copying eland_extended files"
    listOfFiles = Dir["*eland_extended*"]
    listOfFiles.each { |file|
      copyUsingRsync(file)
    }
  end

  def copyExportFiles()
    puts "Copying export files"
    listOfFiles = Dir["*export*"]
    listOfFiles.each { |file|
      copyUsingRsync(file)
    }
  end

  def copyUsingRsync(fileName)
    puts "Copying " + fileName
    cmd = "rsync -az " + fileName + " " + @miniDir
    output = `#{cmd}`
    puts "Output of copy cmd : " + output.to_s

    # Verify that complete file is copied
    cmd = "rsync --dry-run -avz " + fileName + " " + @miniDir
    output = `#{cmd}`
    lines = output.split("\n")

    if lines[1] == ""
      puts "File : " + fileName + " copied successfully"
      # Since the file is copied properly, zip it
      cmd = "bzip2 " + @miniDir + "/" + fileName
      puts "Zipping file : " + fileName
      output = `#{cmd}`
      puts "Completed zipping " + fileName
    else
      puts "Error : file : " + fileName + " was not copied"
    end
  end
end

obj=MiniAnalysis.new
obj.copyFiles()
