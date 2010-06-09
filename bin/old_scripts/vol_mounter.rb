#!/usr/bin/env ruby
#
# Author::    David Rio Deiros  (mailto:deiros@bcm.edu)
# Copyright:: Copyright (c) 2008 David Rio Deiros
# License::   BSD
#
# vim: tw=80 ts=2 sw=2 
#
# Mount all the instrument volumes and the final dump volume
#

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")
require 'babydump'

def help
  puts "Usage #{__FILE__} mount|umount"; exit
end

module Volumes

  I_MP = "/mnt/slx/instruments"
  D_MP = "/mnt/slxdump"
  VOLS = {
    :slxdump  => Babydump::Mount::Fuse_dealer.new("192.168.10.5", 
                "sol-pipe", "/slxdump2/incoming", D_MP),
    :inst_034 => Babydump::Mount::Smb_dealer.new("sbsuser",
                "sbs123", "//192.168.10.8/D$", "#{I_MP}/034"),
    :inst_376 => Babydump::Mount::Smb_dealer.new("sbsuser",
                "sbs123", "//192.168.10.9/D$", "#{I_MP}/376")
  }

  def self.mount
    VOLS.each do |name, vol|
      begin
        puts "Trying to mount #{name}"
        VOLS[name].mount
      rescue
        puts "Couldn't mount #{name}"
        next
      end
    end
  end

  def self.umount
    VOLS.each do |name, vol|
      begin
        puts "Trying to umount #{name}"
        VOLS[name].umount
      rescue
        puts "Couldn't mount #{name}"
        next
      end
    end
  end
end

case ARGV[0]
  when 'mount'
    Volumes::mount 
  when 'umount'
    Volumes::umount
  else
    help
end
