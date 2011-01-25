#!/usr/bin/ruby

# Cleans the unwanted and large position files from the intensity directories
# and qseq files from the # base calls directory.
# THIS MUST BE PERFORMED ONLY AFTER ALL THE ANALYSIS IS COMPLETED
class CleanFlowcell
  def initialize(baseDir)
    puts "Cleaning Flowcells in Dir : " + baseDir.to_s

    flowcells = Dir.entries(baseDir)

    flowcells.each do |fcName|
      puts fcName
      if File.directory?(baseDir + "/" + fcName) && !fcName.eql?(".") &&
         !fcName.eql?("..")
        pwd = Dir.pwd
  
        Dir.chdir(baseDir + "/" + fcName)

        if File.exists?("./Data")
          puts "Found data directory. Time to remove unwanted files"
          cleanIntensityDir()
          cleanBaseCallsDir()
        else
          puts fcName + " does not have data directory"
        end
        puts "Completed cleaning " + fcName
        puts ""
        Dir.chdir(pwd)
      end
    end
  end

  private
  def cleanIntensityDir()
    puts "Cleaning intensity directory"
    rmintensityFilesCmd = "rm ./Data/Intensities/*_pos.txt"
    output = `#{rmintensityFilesCmd}`
    puts output

    rmLanesDirCmd = "rm -rf ./Data/Intensities/L00*"
    output = `#{rmLanesDirCmd}`
    puts "Intensity files cleaned"
  end

  # TODO: Handle multiplexed lanes
  def cleanBaseCallsDir()
    puts "Cleaning basecalls directory"
    rmFilterFilesCmd = "rm ./Data/Intensities/BaseCalls/*.filter"
    output = `#{rmFilterFilesCmd}`

    puts "Removing qseq files"
    rmQseqFilesCmd = "rm ./Data/Intensities/BaseCalls/*_qseq.txt"
    output = `#{rmQseqFilesCmd}`

    puts "Removing lane directories (NOT GERALD)"
    rmLanesDirCmd = "rm -rf ./Data/Intensities/BaseCalls/L00*"
    output = `#{rmLanesDirCmd}`
    puts "BaseCalls directory cleaned"
  end
end


listFile = ARGV[0]

flowcellList = IO.readlines(listFile)

flowcellList.each do |fc|
  puts "Cleaning Flowcell : " + fc.to_s
  obj = CleanFlowcell.new(fc)
end

#obj = CleanFlowcell.new("/stornext/snfs5/next-gen/Illumina/Instruments/EAS376/")
