#!/usr/bin/env ruby
# Author::    David Rio Deiros  (mailto:deiros@bcm.edu)
# Copyright:: Copyright (c) 2008 David Rio Deiros
# License::   BSD
#
# vim: tw=80 ts=2 sw=2 
#
# This lib will help you to interact with slx RUN data. Mounting/umounting
# samba shares, or fuse/sshfs shares. You can extend it if you need more 
# protocols.
#

# Extend the Hash class so we can beautify the output of Cycles (hashes)
class Hash
  def last_cycle
    # C1.1 -> 1
    self.keys.map {|c| c.gsub(/\D|1$/,'').to_i}.sort[-1]
    # We may need this 
    #l_cycles = []
    #(1..cycles[-1]).each { |c| l_cycles << (cycles.include?(c) ? c.to_s : 'X') + ' ' }
  end
end

module Babydump
  module Transfer_logic
    # You have two objects that model the data we have
    # in solexa_dump and the instrument. Extract the necessary
    # data from them and print it so a human can determine if the
    # transfering is going well
    def self.display_data_status(dump_data, inst_data)
      (1..8).each do |l|
        lane  = "L00#{l}"
        # d = dump , n = number of , c = cyles
        dnc = dump_data.images.lanes["L00#{l}"].cycles.size
        inc = inst_data.images.lanes["L00#{l}"].cycles.size
        ldc = dump_data.images.lanes["L00#{l}"].cycles.last_cycle
        lic = inst_data.images.lanes["L00#{l}"].cycles.last_cycle
        puts "#{lane}: i [#{inc}|#{lic}] d [#{dnc}|#{ldc}]"
      end
    end
  end

  # Run cmds
  module Cmds
    def self.error(msg)
      #p msg; exit 1
      raise msg
    end

    # Run a cmd, capture the exit code and act accordingly
    def self.try_to_run(cmd)
      #puts "cmd: #{cmd}"  
      Kernel.system(*cmd)
      error "Error running: #{cmd}, exitcode: #{$?}" if $? != 0
    end
  end

  # Module to mixin with the specific mounting classes
  module Mount
    module Common
      def mount
        Cmds::try_to_run(cmd_mount)
      end
      
      def umount
        Cmds::try_to_run(cmd_umount)
      end
    end

    # Class to deal with Fuse/sshfs
    # Examples:
    # (Fuse)
    # slxdump = Babydump::Mount::Fuse_dealer.new("192.168.10.5",
    #           "sol-pipe", "/slxdump2/incoming", "/mnt/slxdump")
    #
    # (Samba)
    # inst_034 = Babydump::Mount::Smb_dealer.new("sbsuser",
    # "password", "//192.168.10.8/D$", "/mnt/slx/instruments/034")
    Fuse_dealer = Struct.new(:host, :user, :m_path, :l_path) do
      include Common

      def cmd_mount
        sshfs_options = "-o allow_other,default_permissions"
        "sshfs #{sshfs_options} #{user}@#{host}:#{m_path} #{l_path}"
      end

      def cmd_umount
        "sudo umount #{l_path}"
      end
    end

    # Class to deal with samba shares
    Smb_dealer = Struct.new(:user, :pwd, :m_path, :l_path) do
      include Common

      def cmd_mount
        "sudo mount -t cifs " +
        "-o username=#{user},password=#{pwd} #{m_path} #{l_path}"
      end

      def cmd_umount
        "sudo umount #{l_path}"
      end
    end
  end

  # Iterate over FC dirs
  module Fc_finder
    def self.each(path)
      raise "FC path not found: #{path}" unless File.exists?(path)
      Dir["#{path}/*_USI*"].each do |fc| 
        yield File.basename(fc) unless test_or_prep(fc)
      end 
    end

    # Skip FC names we are not interested on
    def self.test_or_prep(fc)
      %w{test prep}.inject(false) { |acc, s| acc || (/#{s}/i =~ fc) }
    end
  end

  # Models a slx run and the data on it
  class Solexa_run
    attr_reader :images

    def initialize(path)
      raise "FC path not found: #{path}" unless File.exists?(path)
      @fc_path = path
      @images  = Images.new("#{path}/Images")
    end

    class Images
      def initialize(path)
        raise "FC path not found: #{path}" unless File.exists?(path)
        @path  = path
        @hlanes = {}
      end

      def lanes
        Dir["#{@path}/L*"].each { |l| @hlanes[File.basename(l)] = Lane.new(l) }
        @hlanes
      end

      class Lane
        def initialize(path)
          raise "Lane path not found: #{path}" unless File.exists?(path)
          @path    = path
          @hcycles = {}
        end

        def cycles
          Dir["#{@path}/C*"].each do |c| 
            @hcycles[File.basename(c)] = Cycle.new(c) 
          end
          @hcycles
        end

        class Cycle
          def initialize(path)
            raise "Cycle path not found: #{path}" unless File.exists?(path)
            @path  = path
            @htiles = Hash.new { |hash, key| hash[key] = Array.new }
          end

          def tiles
            (1..99).each do |t_num|
              Dir["#{@path}/s_*_#{t_num}_*.tif"].each do |t| 
                @htiles[t_num.to_s] << t 
              end
            end
            @htiles
          end
        end
      end
    end
  end
end
