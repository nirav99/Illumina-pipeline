#!/usr/bin/env ruby
# Author::    David Rio Deiros  (mailto:deiros@bcm.edu)
# Copyright:: Copyright (c) 2008 David Rio Deiros
# License::   BSD
#
# vim: tw=80 ts=2 sw=2

require 'find'
require 'date'

# Namespace for the MiniAnalysis project for SLX
module MiniAnalysis

  # Put all the config stuff here
  module CFG
    # Define here what files you want to use from the analysis
    # The value is the expected number of files that match the regexp
   A_FILES      = { /\bSummary.xml/ => 1, /Data\/.params$/  => 8,
                    /\bSummary.xsl/ => 1, /\bSummary.htm/  => 1,
                    /sorted/ => 8, /eland_extended/  => 8,
                     /sequence/    => 8, /eland_multi/     => 8 }
    # For summary we should see only one file, but for sequence 8 or 16
    VALID_NFILES = [ 1, 8, 16 ]
    SSH_USER     = "sol-pipe"
    AWORK_ROOT   = "/data/slx/slxarchivework_X"
    GOATS_ROOT   = "/data/slx/goats/"
    INST_WDIRS   = { "EAS034" => "9" , "EAS376" => "10", "EAS09" => "7" }
    PROD_HOSTS   = [ "r43b-20.hgsc.bcm.edu", "r43b-21.hgsc.bcm.edu",
                   "r44a-40.hgsc.bcm.edu" ] 
    RSYNC_CMD    = "rsync -avz -e ssh "
  end

  # Agropate the methods that we can reuse for other mini projects
  module Helpers

    # Get the FC name based on the directory we are on right now
    def self.local_fc_name
      Dir.pwd.split("/")[-1]
    end

    # Create the necessary dirs in archive work
    def self.create_remote_mini_dir
      a_work_num = CFG::INST_WDIRS[instrument_name]
      p_path     = CFG::AWORK_ROOT.gsub(/X/, a_work_num.to_s)
      f_path     = "#{p_path}/#{local_fc_name}/mini_analysis"
      cmd        = "mkdir -p #{f_path}"
      run_cmd "#{ssh_string(cmd)}"
      f_path
    end

    # Create a goat link with today's date
    def self.create_goat(a_work_dir)
      partial_dst = CFG::GOATS_ROOT + goat_today_dir
      dst = partial_dst + "/" + local_fc_name
      cmd = "mkdir -p #{partial_dst}"
      run_cmd "#{ssh_string(cmd)}"
      cmd = "ln -s #{a_work_dir} #{dst}"
      run_cmd "#{ssh_string(cmd)}"
    end

    # Rsync a ++file++ to +dst+
    def self.rsync_file(file, dst)
      run_cmd "#{CFG::RSYNC_CMD} #{file} " +
              "#{CFG::SSH_USER}@#{random_dst_host}:#{dst}"
      run_cmd "#{CFG::RSYNC_CMD} --dry-run #{file} " +
              "#{CFG::SSH_USER}@#{random_dst_host}:#{dst}"
    end

    # Get the current instrument name base on the dir you are in
    def self.instrument_name
      local_fc_name.match(/(EAS\d+)/)[1]
    end

    # Create a full a remote cmd (based on ssh)
    def self.ssh_string(cmd)
      "ssh #{CFG::SSH_USER}@#{random_dst_host} #{cmd}"
    end

    # Today's date in filesystem format
    def self.goat_today_dir
      today = Date.today

      fixed_month = today.month
      fixed_day = today.day

      if today.month < 10
        fixed_month = "0#{today.month}"
      end

      if today.day < 10
        fixed_day = "0#{today.day}"
      end  

      "#{today.year}/#{fixed_month}/#{fixed_day}"
    end

    # give me a random production server
    def self.random_dst_host
      CFG::PROD_HOSTS[rand(3)-1]
    end

    # Run or print the cmd
    def self.run_cmd(cmd)
      p "CMD: "   + cmd
      p "OUTPUT:" + `#{cmd}`
    end
  end

  # Encapsulates what the concept: group of files of type x
  # For example: summary -> summary.htm, but sequence has
  # 8 or 16 files in the analysis if a MP run.
  class GroupFile
    def initialize(r_e_name)
      @r_e_name  = r_e_name
    end

    # Find me a file(s) that matches the +f_name+ regexp and return its path
    # Raise expection if you cannot find any file that matches +f_name+
    # Raise expection if we get an unexpected number of files
    def get_files
      p_file = []
      Find.find(".") { |path| p_file << path if path =~ @r_e_name }
      raise "no files found for: #{@r_e_name}" if p_file.size < 1
      raise "wrong n_files: #{@r_e_name}" if CFG::VALID_NFILES.include?(p_file.size + 1)
      p_file
    end

    # Iterate over the files on each group
    def each_file
      get_files.each { |file| yield file }
    end
  end
end
