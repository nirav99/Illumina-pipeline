#!/usr/bin/env ruby
# Author::    David Rio Deiros  (mailto:deiros@bcm.edu)
# Copyright:: Copyright (c) 2008 David Rio Deiros
# License::   BSD
#
# vim: tw=80 ts=2 sw=2
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'asshaul.rb'
require 'slx_symlinks.rb'

# RegExp to do against each DIR on the origin
care_rexp  = /EAS376/
log_file   = "/data/slx/slxarchive_8/.incoming.queue/logs/EAS376.log"
# We'll save here the list of FCs that are done or are NEW
done_items =  StoreItems.new("/data/slx/slxarchive_8/.incoming.queue/logs/done_items.EAS376")
new_items  =  StoreItems.new("/data/slx/slxarchive_8/.incoming.queue/logs/new_items.EAS376")
lock       =  Locker.new("/data/slx/slxarchive_8/.incoming.queue/logs/lock.EAS376")
# Origin/dst (origin is a remove machine we'll access via ssh, dst is local)
#ssh_url    = "sol-pipe@solexa-dump-1:/slxdump2/incoming"
ssh_url    = "sol-pipe@172.30.18.12:/slxdump2/incoming"
origin     = Source.new(ssh_url, care_rexp, done_items)
dst        = "/data/slx/slxarchive_8"
machine_dir= "/data/slx/USI-EAS376/Runs"
work_dir   = "/data/slx/slxarchivework_10"
rsync      = Rsync.new(ssh_url, dst)

# CC to
Emailer.instance.ccs << 'dc12@bcm.edu'
Emailer.instance.ccs << 'niravs@bcm.edu'
Emailer.instance.ccs << 'yhan@bcm.edu'
# Use a file as a log instead the STDOUT
SingleLogger.instance.set_output(log_file)

# Use the locker to determine if we can start another instance of this
SingleLogger.instance.info "Checking if another instance is running ..."
if !lock.try_to_lock
  SingleLogger.instance.info "Another instance is running"
  exit 0
end

SingleLogger.instance.info "Loading items for #{origin} ..."
origin.load_items

# Iterate over each item that matches what we wan
origin.each_care_item do |item|
  SingleLogger.instance.info "working on #{item}"

  # We have a new item.. we should inform the user
  if !new_items.exists?(item)
    SingleLogger.instance.info "New item found: #{item}"
    Emailer.instance.send("- asshaul: New item (#{item})")
    new_items.add(item)
  end

  # Transfer whatever has changed in the origin to the ds
  rsync.transfer(item)

  # If we are done (flag detected + it's fully copied) inform the user
  if item.is_done? && rsync.fully_copied?(item)
    # create empty Data dir and sym link to it
    SetSymlinks.keep_data(dst, work_dir, machine_dir, item)
    SingleLogger.instance.info "#{item} is DONE + FULLY_TRANSFERRED"
    item.done
    done_items.add(item)
    Emailer.instance.send("- asshaul: #{item} fully transferred")
  end
end

lock.unlock
SingleLogger.instance.info "Bye"
