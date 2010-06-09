#!/usr/bin/env ruby
#
# Author::    David Rio Deiros  (mailto:deiros@bcm.edu)
# Copyright:: Copyright (c) 2008 David Rio Deiros
# License::   BSD
#
# vim: tw=80 ts=2 sw=2 
#
# This code will help us to determine when there are issues
# in the Images transfers between Instrument and SolexaDump.
#

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")
require 'babydump'

dump_path = "/mnt/slxdump"
inst_path = "/mnt/slx/instruments"

# Iterate over each FC in slxdump
Babydump::Fc_finder.each(dump_path) do |fc|
  fc_name = File.basename(fc)
  puts "----> " + fc_name
  instrument = fc.match(/(376|034)/)[1]

  # Try to read the data in sdump and in the instrument
  begin
    d_data = Babydump::Solexa_run.new("#{dump_path}/#{fc}")
    i_data = Babydump::Solexa_run.new("#{inst_path}/#{instrument}/Runs/#{fc}")
  rescue
    # It's ok if there are no images the sources -> Run removed from instrument
    if $!.to_s =~ /path not found/ 
      puts $!
      next 
    end
    raise "Fatal error, bailing out"
  end

  # Try to display what's the status of that FC
  begin
    Babydump::Transfer_logic.display_data_status(d_data, i_data)
  rescue
    #puts "--- "; slxdump.umount; inst_376.umount ; inst_034.umount
    raise $!
  end
  puts ""
end
