#!/usr/bin/env ruby
#
# this file will take a tab delimited file for slx,
# parse the fields and populate to the slx lims database
#
# usage ruby parse_tab.rb <tab delimited file_name>
#
# vim: tw=80 ts=2 sw=2
#
input_file = ARGV[0]
fields     = "/data/slx/goats/hgsc_slx/templates/fields.txt"

# Removes the field that does not have data from field_names
def check_fields(stats, fields)
  temp = Array.new(fields)
	temp.each { |x| temp.delete(x) if stats["#{x}"] == "" }
end

raise "you need to specify a file "  if input_file.nil?
raise "#{input_file} does not exist" if !File.exist?(input_file)

# Read first line and order the input
l = File.open(input_file, "r").read.split("\n")

# Read in all of the params
field_name = File.open(fields, "r").read.split

l[1..l.length-1].each do |x|
  line_stats = Struct.new(:FC, :RUN_DATA, :Instrument, :Lane, :Name,
                          :Sample, :Project, :Source, :Column3, :Length,
                          *field_name)

  # Instantiate a stat lines with the input data
  l_stats = line_stats.new(*x.split("\t"))

  # Construst the params for the perl script
  fc = "#{l_stats.FC}-#{/\d/.match(l_stats.Lane)}"
  fc_code = fc.slice(2,fc.size)
  checked_fields = check_fields(l_stats, field_name)
  field_string = ""
  checked_fields.each { |x| field_string += "#{x} #{l_stats["#{x}"]} " }

  puts "perl setIlluminaLaneStatus.pl #{fc_code} ANALYSIS_FINISHED #{field_string}"
  p_script="/data/slx/goats/hgsc_slx/third_party/setIlluminaLaneStatus.pl"
#  `perl #{p_script} #{fc} ANALYSIS_FINISHED #{field_string}`
end
