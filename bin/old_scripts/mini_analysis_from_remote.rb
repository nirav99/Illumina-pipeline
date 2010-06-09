#!/usr/bin/env ruby
# Author::    David Rio Deiros  (mailto:deiros@bcm.edu)
# Copyright:: Copyright (c) 2008 David Rio Deiros
# License::   BSD
#
# vim: tw=80 ts=2 sw=2
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'mini_analysis'
require 'mini_analysis_summary'

# Every group of files will have an entry in this hash
group_files = {}
MiniAnalysis::CFG::A_FILES.each do |r_exp, n_files|
  group_files[r_exp] = MiniAnalysis::GroupFile.new(Regexp.new(r_exp))
end

# create the dst directories archive_work and goats FS structure and
remote_aw_dir = MiniAnalysis::Helpers::create_remote_mini_dir
MiniAnalysis::Helpers::create_goat(remote_aw_dir)

# Rsync all the files
MiniAnalysis::CFG::A_FILES.each_key do |r_exp|
  group_files[r_exp].each_file do |f|
    if /Summary.xml/.match(f)
      MiniAnalysisXMLSummary::grabSummary(f, remote_aw_dir)
    elsif /Summary.xsl/.match(f)
      MiniAnalysisXSLSummary::grabSummary(f, remote_aw_dir)
    elsif /Summary.htm/.match(f)
      MiniAnalysisHTMSummary::grabSummary(f, remote_aw_dir)
    else
      MiniAnalysis::Helpers::rsync_file(f, remote_aw_dir)
    end
  end
  puts "-------"
end
