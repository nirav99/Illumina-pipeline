#!/usr/bin/env ruby
#
# Author: David Chen  (mailto:dc12@bcm.edu)
#
# vim: tw=80 ts=2 sw=2

require 'fileutils'
require 'asshaul.rb'

module SetSymlinks
  # this is method will create all the slx symlinks
  def self.symlinks(machine_dst, img_dst, work_dst)
    FileUtils.remove_dir "#{img_dst}/Data"  # Remove Data from slxarchive
    # Symlink of Data from slxarchivework to slxarchive
    FileUtils.ln_s("#{work_dst}/Data", "#{img_dst}/Data")
    # Symlink of the FC in USI-EAS#/Runs
    FileUtils.ln_s(img_dst, machine_dst)
  end
  
  # this method will keep the data dir from the solexa transfer
  def self.keep_data(dst, work_dir, machine_dir, item)
    @work_dst    = "#{work_dir}/#{File.basename(item.to_s.chomp)}"
    @img_dst     = "#{dst}/#{File.basename(item.to_s.chomp)}"
    @machine_dst = "#{machine_dir}/#{File.basename(item.to_s.chomp)}"
    FileUtils.mkdir(@work_dst)
    # Transfer the Data from slxarchive to slxarchviework
    sync_to_slxwrk = Rsync.new(@img_dst, @work_dst)
    sync_to_slxwrk.transfer("Data")
    symlinks(@machine_dst, @img_dst, @work_dst) 
  end

  # this method will remove the data dir from solexa and create an empty one
  def self.new_data(dst, work_dir, machine_dir, item)
    work_dst    = "#{work_dir}/#{File.basename(item.to_s.chomp)}"
    img_dst     = "#{dst}/#{File.basename(item.to_s.chomp)}"
    machine_dst = "#{machine_dir}/#{File.basename(item.to_s.chomp)}"
    FileUtils.mkdir_p("#{work_dst}/Data")
    symlinks(machine_dst, img_dst, work_dst) 
  end 
end
