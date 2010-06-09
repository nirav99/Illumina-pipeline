#!/usr/bin/env ruby
#
# $Id: slx_rss.rb 495 2008-04-18 15:51:48Z dc12 $
#
#
require 'rss/maker'
require '/data/slx/goats/hgsc_slx/lib/summary_info.rb'

#fcs_file = "/users/sol-pipe/.drio/src/solexa_rss/.completedFCSummary.txt"
fcs_file = "/data/slx/goats/hgsc_slx/lib/.completedFCSummary.txt"

goat_file ="/data/slx/USI-EAS09/webs/prod-solexa/htdocs/goats/goats.txt"
#destination = "/users/sol-pipe/.drio/src/solexa_rss/solexa-rss.tmp.xml"
destination = "/data/slx/goats/hgsc_slx/solexa-rss.tmp.xml"



# This method will jog the name of the parsed summary into
#  "#{ENV['HOME']}/.completedFCSummary.txt"
def completed_FC_summary(dir, fcs_file)
  file = File.open(fcs_file,"a")
  file.puts(dir)
  file.close
end

# parse the date from format yymmdd and returns yyyy/mm/dd
# takes in an array consist of {dd, mm, yy, yymmdd}
def parse_dates(orig_date)
  orig_date.pop
  year = "20#{orig_date.pop.to_s}"
  month = orig_date.pop.to_s
  day = orig_date.pop.to_s
  return "#{year}/#{month}/#{day}"
end

summaries = Array.new 
f = File.open(goat_file, "r")  
while ( summary = f.gets ) #gathers all the paths from goats.txt
    sample_dir, outputs, outputs_b = run_parse_summary(summary.chomp, fcs_file)
  if !outputs.empty?
    title = "#{outputs["fc"]} #{outputs["sample"]} #{outputs["type"]} L#{outputs["Lane"]}"
    date = "#{outputs["date_created"]}"
    info = "<table>"
    if outputs["Lane Yield (kbases)"] == nil
      file_format = "old_summary_keys.txt"
    else
      file_format = "new_summary_keys.txt"
    end

    file = File.open(file_format, "r")
    while (line = file.gets)
      info += "<tr><td>#{line}</td><td>#{outputs[line.chomp].to_s}</td></tr>"
    end
    file.close

    if !outputs_b.empty?
      file = File.open(file_format, "r")
      info += "<tr><td><b>Read 2</b></td></tr>"
      while (line = file.gets)
        info += "<tr><td>#{line}</td><td>#{outputs[line.chomp].to_s}</td></tr>"
      end
      file.close
    end
    info += "</table>"
    summaries << {:title => title, :date => date, :info => info}
#    completed_FC_summary(sample_dir, fcs_file)
  end
end
f.close

# creating the rss feeds
if !summaries.empty?
  version = "2.0"
  content = RSS::Maker.make(version) do |m|
    m.channel.title = "Solexa Summary RSS feeds"
    m.channel.link = "http://www.rubyrss.com"
#    m.channel.link = "http://prod-solexa.hgsc.bcm.tmc.edu/rss/solexa-rss.xml"
    m.channel.description = "old news (or new olds) at Ruby RSS"
    m.items.do_sort = true # sort items by date

    summaries.each do |x|
      i = m.items.new_item
      i.title = x[:title].to_s
      i.description = x[:info].to_s
      i.date = Time.parse( parse_dates(/([0-9][0-9])([0-9][0-9])([0-9][0-9])/.match(x[:date].to_s).to_a.reverse) )
    end
  end
  File.open(destination,"w") do |f|
    f.write(content)
  end
end
