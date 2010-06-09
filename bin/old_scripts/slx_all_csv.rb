#!/usr/bin/env ruby
#
# $Id: slx_csv.rb 477 2008-04-04 14:28:40Z dc12 $
#
require '/data/slx/goats/hgsc_slx/lib/summary_info.rb'
#fcs_file = "/users/sol-pipe/.drio/src/solexa_rss/.completedFCALLcsv.txt"
fcs_file = "/data/slx/goats/hgsc_slx/lib/.completedFCALLcsv.txt"
goat_file = "/data/slx/USI-EAS09/webs/prod-solexa/htdocs/goats/goats.txt"
destination_all = "/data/slx/goats/hgsc_slx/lib/slx_data.all.tmp.csv"
#destination_all = "/users/sol-pipe/.drio/src/solexa_rss/slx_data.all.tmp.csv"
fc_fields = "/data/slx/goats/hgsc_slx/templates/fc_fields.txt"
full_summary_keys = "/data/slx/goats/hgsc_slx/templates/combined_summary_keys.txt"
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

if !File::exist?(destination_all)
  info = fc_header(fc_fields)
  info += fc_header(full_summary_keys)
  info += ","
  info += fc_header(full_summary_keys)
  info = info.chop
  info += "\n"
  File.open(destination_all,"w") do |destfile|
    destfile.write(info)
  end
end


info = ""

summaries = Array.new
f = File.open(goat_file, "r")
while ( summary = f.gets ) #gathers all the paths from goats.txt
  sample_dir, outputs, outputs_b = run_parse_summary(summary.chomp, fcs_file)
  if !outputs.empty?
    file = File.open(fc_fields, "r")
    while (line = file.gets)
      info += "#{outputs[line.chomp].to_s.chomp},"
    end
    file.close
    file_format = full_summary_keys
    file = File.open(file_format, "r")
    while (line = file.gets)
      if outputs["Lane Yield (kbases)"] == nil
        if line.chomp == "Clusters (raw)"
          info += "#{outputs["Clusters"].to_s.chomp},"
        elsif line.chomp == "+/- SD Clusters (raw)"
          info += "#{outputs["+/- SD Clusters"].to_s.chomp},"
        else
          info += "#{outputs[line.chomp].to_s.chomp},"
        end
      else 
        info += "#{outputs[line.chomp].to_s.chomp}," 
      end
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
    File.open(destination_all,"a") do |destfile|
      destfile.write(info)
    end
    completed_FC_summary(sample_dir, fcs_file) 
    info =""
  end
end
f.close
