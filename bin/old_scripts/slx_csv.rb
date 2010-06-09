#!/usr/bin/env ruby
#
# $Id: slx_csv.rb 495 2008-04-18 15:51:48Z dc12 $
#

require '/data/slx/goats/hgsc_slx/lib/summary_info.rb'
#fcs_file = ".completedFCcsv.txt"
fcs_file = "/data/slx/goats/hgsc_slx/lib/.completedFCcsv.txt"
goat_file = "/data/slx/USI-EAS09/webs/prod-solexa/htdocs/goats/goats.txt"
#destination_old = "slx_data.old.tmp.csv"
#destination_current = "/users/sol-pipe/.drio/src/solexa_rss/slx_data.current.tmp.csv"
destination_current = "/data/slx/goats/hgsc_slx/lib/slx_data.current.tmp.csv"
fc_fields = "/data/slx/goats/hgsc_slx/templates/fc_fields.txt"
new_summary_keys = "/data/slx/goats/hgsc_slx/templates/new_summary_keys.txt"

# This method will jog the name of the parsed summary into
#  "#{ENV['HOME']}/.completedFCSummary.txt"
def completed_FC_summary(dir, fcs_file)
  file = File.open(fcs_file,"a")
  file.puts(dir)
  file.close
end

# reads in the fc data headings from a passed in file
# return the string with commas between each field
# and a new line at the end
def fc_header(header_file)
  tmp = ""
  file = File.open(header_file, "r")
  while (line = file.gets)
    tmp += "#{line.chomp},"
  end
  file.close
  return tmp 
end

#if !File::exist?(destination_old)
#  info = fc_header(fc_fields)
#  info += fc_header("old_summary_keys.txt")
#  info += "\n"
#  File.open(destination_old,"w") do |destfile|
#    destfile.write(info)
#  end
#end
if !File::exist?(destination_current)
  info = fc_header(fc_fields)
  info += fc_header(new_summary_keys)
  info += ","
  info += fc_header(new_summary_keys) 
  info = info.chop
  info += "\n"
  File.open(destination_current,"w") do |destfile|
    destfile.write(info)
  end
end

info = ""
summaries = Array.new
f = File.open(goat_file, "r")
while ( summary = f.gets ) #gathers all the paths from goats.txt
  sample_dir, outputs, outputs_b = run_parse_summary(summary.chomp, fcs_file)
#sample_dir, outputs, outputs_b = run_parse_summary(fc_path, fcs_file)
  if !outputs.empty? && outputs["Lane Yield (kbases)"] != nil  #skips old format
    file = File.open(fc_fields, "r")
    while (line = file.gets)
      info += "#{outputs[line.chomp].to_s.chomp},"
    end
    file.close
#    if outputs["Lane Yield (kbases)"] == nil
#      file_format = "old_summary_keys.txt"
#    else
    file_format = new_summary_keys
#    end
    file = File.open(file_format, "r")
    while (line = file.gets)
      info += "#{outputs[line.chomp].to_s.chomp},"
    end
    file.close
    if !outputs_b.empty?
      file = File.open(file_format, "r")
      info += "Read 2,"
      while (line = file.gets)
        info += "#{outputs[line.chomp].to_s.chomp},"
      end
      file.close
    end
    info = info.chop
    info += "\n"
    if file_format == "old_summary_keys.txt"
      File.open(destination_old,"a") do |destfile|
        destfile.write(info)
      end
    else
      File.open(destination_current,"a") do |destfile|
        destfile.write(info)
      end
    end
    completed_FC_summary(sample_dir, fcs_file) 
    info =""
  end
end
f.close
