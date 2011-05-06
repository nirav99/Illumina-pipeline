#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'Scheduler'
require 'PipelineHelper'

# This script is run after BWA alignment completes.

# Upload results to LIMS
uploadLIMSResultsCmd = "ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/upload_LIMS_results.rb 1>limsResultUpload.o 2>limsResultUpload.e"
output = `#{uploadLIMSResultsCmd}`
puts "Output from LIMS : " + output

# Send analysis result email
emailAnalysisResultCmd = "ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/ResultMailer.rb"
output = `#{emailAnalysisResultCmd}`

# Upload the mapping results file to LIMS (if it exists)
uploadBAMAnalyzerFileCmd = "ruby /stornext/snfs5/next-gen/Illumina/ipipe/bin/uploadBAMAnalyzerFile.rb"
output = `#{uploadBAMAnalyzerFileCmd}`

# Appropriate code can be added here to clean up the GERALD directory of
# unwanted files such as .sam, intermediate .bam files, .sai files etc.
puts "Deleting Temp Files"
deleteTempFilesCmd = "rm *.sam *.sai *_sanger_sequence.txt"
`#{deleteTempFilesCmd}`

# Be careful here, delete only _sorted.bam
puts "Deleting intermediate BAM file"
deleteTempBAMFileCmd = "rm *_sorted.bam"
`#{deleteTempBAMFileCmd}`

puts "Deleting Temporary Directories"
deleteTempDirCmd = "rm -rf ./Stats ./Temp ./Plots"
`#{deleteTempDirCmd}`

puts "Deleting Temporary Files"
deleteTempFilesCmd = "rm *_tiles.txt *_finished.txt finished.txt tiles.txt"
`#{deleteTempFilesCmd}`

puts "Zipping sequence files"
zipCommand = "bzip2 *sequence.txt"
`#{zipCommand}`
