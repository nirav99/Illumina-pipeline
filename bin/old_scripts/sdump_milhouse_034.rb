#!/usr/bin/env ruby
# Author::    David Rio Deiros  (mailto:deiros@bcm.edu)
# Copyright:: Copyright (c) 2008 David Rio Deiros
# License::   BSD
#
# vim: tw=80 ts=2 sw=2
$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'asshaul.rb'

# RegExp to do against each DIR on the origin
care_rexp  = /EAS034/
log_file   = "/mnt/slx/asshaul_logs/EAS034.log"
# We'll save here the list of FCs that are done or are NEW
done_items = StoreItems.new("/mnt/slx/asshaul_logs/done_items.EAS034")
new_items  = StoreItems.new("/mnt/slx/asshaul_logs/new_items.EAS034")
lock       = Locker.new("/mnt/slx/asshaul_logs/lock.EAS034")
# Origin/dst (origin is a remove machine we'll access via ssh, dst is local)
ssh_url    = "sol-pipe@192.168.10.5:/slxdump2/incoming"
origin     = Source.new(ssh_url, care_rexp, done_items)
dst        = "/mnt/slx/incoming"
rsync      = Rsync.new(ssh_url, dst)

# CC to
Emailer.instance.to << 'deiros@bcm.edu'
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
    SingleLogger.instance.info "#{item} is DONE + FULLY_TRANSFERED"
    item.done
    done_items.add(item)
    Emailer.instance.send("- asshaul: #{item} fully transfered")
  end
end

lock.unlock
SingleLogger.instance.info "Bye"
