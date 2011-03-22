#!/usr/bin/ruby

# A simple script to rebuild all Java projects in the Illumina pipeline.

currDir = Dir.pwd

dirEntries = Dir::entries(currDir)

dirEntries.each do |entry|
  if File::directory?(entry) && File::exist?( "./" + entry + "/GenerateJAR.sh")
    puts "Rebuilding project : " + entry.to_s
    Dir.chdir(entry)
    cmd = "sh ./GenerateJAR.sh"
    output = `#{cmd}`
    puts output
    cmd = "cp *.jar ../"
    `#{cmd}`
    Dir.chdir(currDir)
  end
end
