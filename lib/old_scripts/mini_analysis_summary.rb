#!/usr/bin/env ruby
# Author::    David Chen  (mailto:dc12@bcm.edu)
#
# vim: tw=80 ts=2 sw=2

require 'mini_analysis'
require 'rubygems'
require 'hpricot'

# this module allows mini_analysis to grab multiple Summary.htm and rename it
# to Summary_#.htm where # is the lane number
module MiniAnalysisHTMSummary
  def self.grabSummary(summary_path, dest)

    #get lane numbers directly from summary & modify name to reflect lanes
    output = ""; text = ""; path = "" 
    path = summary_path.split("/Summary.htm")[0]
    summary = "#{path}/Summary.xml"    
    doc = Hpricot::XML(open("#{summary}"))
    (doc/:'LaneResultsSummary Read').each do|read|
      readNumber = (read/'readNumber').inner_html
      if(readNumber != "2")
        (read/'Lane').each do|lane|
          laneNumber = (lane/'laneNumber').inner_html
          laneYield = (lane/'laneYield').inner_html
          if(laneYield != "")
            text += "_#{laneNumber}"
          end
        end
        output = "Summary#{text}.htm"
      end
    end

    #concat the path with the desired file name
    final_dest = "#{dest}/#{output}"

    #rsync the summary files to mini_analysis
    MiniAnalysis::Helpers::rsync_file(summary_path, final_dest)
  end
end

# this module allows mini_analysis to grab multiple Summary.xsl and rename it
# to Summary_#.xsl where # is the lane number
module MiniAnalysisXSLSummary
  def self.grabSummary(summary_path, dest)

    #get lane numbers directly from summary & modify name to reflect lanes
    output = ""; text = ""; path = "" 
    path = summary_path.split("/Summary.xsl")[0]
    summary = "#{path}/Summary.xml"
    doc = Hpricot::XML(open("#{summary}"))
    (doc/:'LaneResultsSummary Read').each do|read|
      readNumber = (read/'readNumber').inner_html
      if(readNumber != "2")
        (read/'Lane').each do|lane|
          laneNumber = (lane/'laneNumber').inner_html
          laneYield = (lane/'laneYield').inner_html
          if(laneYield != "")
            text += "_#{laneNumber}"
          end
        end
        output = "Summary#{text}.xsl"
      end
    end

    #concat the path with the desired file name
    final_dest = "#{dest}/#{output}"

    #rsync the summary files to mini_analysis
    MiniAnalysis::Helpers::rsync_file(summary_path, final_dest)
  end
end

# this module allows mini_analysis to grab multiple Summary.xml and rename it
# to Summary_#.xml where # is the lane number
module MiniAnalysisXMLSummary
  def self.grabSummary(summary_path, dest)

    #get lane numbers directly from summary & modify name to reflect lanes
    output = ""; text = ""; path = ""
    path = summary_path.split("/Summary.xml")[0]
    summary = "#{path}/Summary.xml" 
    doc = Hpricot::XML(open("#{summary}"))
    (doc/:'LaneResultsSummary Read').each do|read|
      readNumber = (read/'readNumber').inner_html
      if(readNumber != "2")
        (read/'Lane').each do|lane|
          laneNumber = (lane/'laneNumber').inner_html
          laneYield = (lane/'laneYield').inner_html
          if(laneYield != "")
            text += "_#{laneNumber}"
          end
        end
        output = "Summary#{text}.xml"
      end
    end

    #concat the path with the desired file name
    final_dest = "#{dest}/#{output}"

    #rsync the summary files to mini_analysis
    MiniAnalysis::Helpers::rsync_file(summary_path, final_dest)
  end
end

