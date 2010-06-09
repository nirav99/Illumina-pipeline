# Author::    David Rio Deiros  (mailto:deiros@bcm.edu)
# Copyright:: Copyright (c) 2008 David Rio Deiros
# License::   BSD
#
# vim: tw=80 ts=2 sw=2
#
require 'logger'
require 'delegate'
require 'singleton'
require 'net/smtp'
require 'fileutils'

# Send emails without relaying on the local smtp server
class Emailer
  include Singleton

  attr_accessor :from, :to, :subject, :body, :ccs, :server, :port

  def initialize
    @from   = 'slx_pipeline@bcm.edu'
    @server = 'smtp.bcm.tmc.edu'
    @port   = 25
    @to     = 'deiros@bcm.edu'
    @ccs    = [ @to ]
    @body   = ''
  end

  # If no body, subject == body
  def send(subject, body=nil)
    @subject = subject
    @body    = body.nil? ? subject : body

    myMessage =  "From: #{@from}\n"
    myMessage << "To: #{@to}\n"
    myMessage << "Subject: #{@subject}\n\n"
    myMessage << "#{@body}\n"

    Net::SMTP.start(server, port) do |smtp|
      # Use array for multiple ccs
      smtp.send_message myMessage, @from, @ccs
    end
  end
end

# Singleton for logging purposes
#  * Use: SingleLogger.instance.set_output("file_here") to log to a file
class SingleLogger < SimpleDelegator
  include Singleton

  # By default, log to STDOUT
  def initialize
    @logger = Logger.new(STDOUT)
    super(@logger)
  end

  # Allow us to change the log device as necessary
  def set_output(log_device)
    __setobj__(Logger.new(log_device))
  end
end

# Encapsulates the interaction with the rsync tool
class Rsync
  # * origin, dst : string (can be sshurl or regular directory path)
  # Notice that I am expecting to have keys authentication in place
  def initialize(origin, dst)
    @rsync_cmd = "rsync -alvz -e ssh"
    @origin    = origin.chomp
    @dst       = dst.chomp
  end

  # Run the actual rsync
  def transfer(item)
    base = File.basename(item.to_s.chomp)
    cmd  = "#{@rsync_cmd} #{@origin}/#{base} #{@dst}"
    SingleLogger.instance.info cmd
    `#{cmd}`
  end

  # Perform a dry-run to see if the data has been fully copied
  def fully_copied?(item)
    base = File.basename(item.to_s.chomp)
    cmd  = "#{@rsync_cmd} --dry-run #{@origin}/#{base} #{@dst}"
    SingleLogger.instance.info cmd
    r_output = `#{cmd}`
    lines = r_output.split("\n")
    lines.size == 4 && lines[1] == ""
  end
end

# And item normally would be a Directory.
class Item
  def initialize(item_url)
    @item_url = item_url
  end

  # Use a regexp to see if we have to deal with this item
  def self.do_i_care?(p_item, reg_exp)
    p_item =~ reg_exp
  end

  # For slx, for example, a Run.completed file has to be present.
  def is_done?
    ssh_url, path = @item_url.split(':')
    `ssh #{ssh_url} ls #{path}/Run.completed 2>/dev/null`.split("\n").size == 1
  end

  # Overwrite this if you want to do something in particular.
  def done
    puts "done: #{@item_url}"
  end

  def to_s; @item_url.to_s; end
end

# Stores items
class StoreItems
  def initialize(file)
    @file = file
    `touch #{file}` if !File.exists?(file)
  end

  def add(item)
    if !exists?(item)
      File.open(@file, "a") { |f| f.puts item.to_s }
    end
  end

  def exists?(item)
    File.open(@file, "r").read =~ /#{item}/
  end
end

# Encapsulates a remote location/directory
class Source
  def initialize(source, care_regexp, done_items)
    @source      = source
    @items       = []
    @care_regexp = care_regexp
    @done_items  = done_items
  end

  def load_items
    ssh_url, path = @source.split(':')
    `ssh #{ssh_url} ls #{path}`.each_line do |f|
      if Item.do_i_care?(f, @care_regexp) && !@done_items.exists?(f)
        @items << Item.new(@source + "/#{f.chomp}")
      end
    end
  end

  def each_care_item
    @items.each { |i| yield i }
  end

  def to_s; @source.to_s end
end

# It helps you to run your scripts based on the library in cron.
class Locker
  def initialize(lock_file)
    @lock = lock_file
  end

  def try_to_lock
    if File.exists?(@lock)
      false
    else
      FileUtils.touch @lock
      true
    end
  end

  def unlock
    FileUtils.rm @lock if File.exists?(@lock)
  end
end
