#!/usr/bin/env ruby
require 'rubygems'
require 'hpricot'

#The purpose of xmlSummaryParser.rb is to extract results summary statistics and
#output the values for each run into LIMS.

#Open the document
doc = Hpricot::XML(open('Summary.xml'))
dir = Dir.pwd

#Initialize variable for results to be retrieved from summary.xml file
fc_code = ""
fc_name = ""
string = ""
laneNumber = []
laneYield = [] 
errorPF = []
clusterCountRaw = []
clusterCountPF = []
avg1stCycleInt = [] 
signal20AsPctOf1 = []
percentClustersPF = []
percentUniquelyAlignedPF = []
averageAlignScorePF = []
phasingApplied = []
prephasingApplied = []  
readNumber = []
clusterCountSD = []
sd1stCycleInt = []
signal20AsPctOf1SD = [] 
percentClustersPFSD = []
percentUniquelyAlignedPFSD = []
stdevAlignScorePF = []
errorPFSD = []
laneHash = {}
laneHash1 = {}
laneHash2 = {}
hash = {}  
lanesUsedForAnalysis = {}

#Read FC name
#Some Flowcell names are of the form blah_blah_blah_FCFlowcell while some are of
#the form blah_blah_blah_FlowCell. Thus, when flow cell name begins with "FC", we
#truncate the these two letters and then assign the resulting value to fc_name.
#However if the flowcell does not begin with "FC", we just use that as the value
#for fc_name
(doc/:'ChipSummary').each do|summary|
  runFolder = (summary/'RunFolder').inner_html
  run = runFolder[/FC(.+)$/]
  if run == nil
   run = runFolder[/([a-zA-Z0-9]+)$/]
   fc_name = run
  else
   fc_name = run.slice(2,run.size)
  end
end

#Read config.txt
#Find the lane numbers from the config file while ignoring the lanes with
#ANALYSIS none
configFileLines = IO.readlines("config.txt")
idx=0
while idx < configFileLines.size do
  if ( configFileLines[idx] =~ /^[1-8]+:ANALYSIS/)  && !(configFileLines[idx] =~ /none/) then
    temp=configFileLines[idx].index(":") - 1
    lanesUsedForAnalysis = configFileLines[idx][0..temp]
    puts "Lane Number(s) = " + lanesUsedForAnalysis
  end
  idx += 1
end

#Read each read entry to determine if the number of reads, then for each read
#obtain the results for each lane. 
(doc/:'LaneResultsSummary Read').each do|read| 
  readNumber = (read/'readNumber').inner_html

  (read/'Lane').each do|lane|
    laneNumber = (lane/'laneNumber').inner_html

#    puts "LaneNumber = " + laneNumber

#    if(lanesUsedForAnalysis.index(laneNumber) != nil)

    laneYield = (lane/'laneYield').inner_html
    errorPF = (lane/'errorPF mean').inner_html
    errorPFSD = (lane/'errorPF stdev').inner_html
    clusterCountRaw = (lane/'clusterCountRaw mean').inner_html
    clusterCountSD = (lane/'clusterCountRaw stdev').inner_html
    clusterCountPF = (lane/'clusterCountPF mean').inner_html
    avg1stCycleInt = (lane/'oneSig mean').inner_html
    sd1stCycleInt = (lane/'oneSig stdev').inner_html
    signal20AsPctOf1 = (lane/'signal20AsPctOf1 mean').inner_html
    signal20AsPctOf1SD = (lane/'signal20AsPctOf1 stdev').inner_html
    percentClustersPF = (lane/'percentClustersPF mean').inner_html
    percentClustersPFSD = (lane/'percentClustersPF stdev').inner_html
    percentUniquelyAlignedPF = (lane/'percentUniquelyAlignedPF mean').inner_html
    percentUniquelyAlignedPFSD = (lane/'percentUniquelyAlignedPF stdev').inner_html
    averageAlignScorePF = (lane/'averageAlignScorePF mean').inner_html
    stdevAlignScorePF = (lane/'averageAlignScorePF stdev').inner_html

    # this is how fields should be checked to see if they are empty and replace
    # their values with zero
    if(percentUniquelyAlignedPFSD == nil || percentUniquelyAlignedPFSD == "")
      percentUniquelyAlignedPFSD = "0"
    end

    if(percentUniquelyAlignedPF == nil || percentUniquelyAlignedPF == "")
      percentUniquelyAlignedPF = "0"
    end

    if(averageAlignScorePF == nil || averageAlignScorePF == "")
      averageAlignScorePF = "0"
    end

    if(stdevAlignScorePF == nil || stdevAlignScorePF == "")
      stdevAlignScorePF = "0"
    end

    if(errorPF == nil || errorPF == "")
      errorPF = "0"
    end

    if(errorPFSD == nil || errorPFSD == "")
      errorPFSD = "0"
    end

#    puts "percentUniquelyAlignedPFSD = " + percentUniquelyAlignedPFSD
#    puts "percentUniquelyAlignedPF = " + percentUniquelyAlignedPF
#    puts "averageAlignScorePF = " + averageAlignScorePF
#    puts "stdevAlignScorePF = " + stdevAlignScorePF

#Extract information for lanes only with summary results.   
    if(laneYield != "")
      hash = ["READ", readNumber, 
      "LANE_YIELD_KBASES", laneYield, 
      "CLUSTERS_RAW", clusterCountRaw, 
      "SD_CLUSTERS_RAW", clusterCountSD, 
      "CLUSTERS_PF", clusterCountPF, 
      "FIRST_CYCLE_INT_PF", avg1stCycleInt,
      "SD_FIRST_CYCLE_INT_PF", sd1stCycleInt, 
      "PERCENT_INTENSITY_AFTER_20_CYCLES_PF", signal20AsPctOf1,
      "SD_PERCENT_INTENSITY_AFTER_20_CYCLES_PF", signal20AsPctOf1SD, 
      "PERCENT_PF_CLUSTERS",  percentClustersPF,
      "SD_PERCENT_PF_CLUSTERS", percentClustersPFSD, 
      "PERCENT_ALIGN_PF", percentUniquelyAlignedPF, 
      "SD_PERCENT_ALIGN_PF", percentUniquelyAlignedPFSD, 
      "ALIGNMENT_SCORE_PF", averageAlignScorePF,   
      "SD_ALIGNMENT_SCORE_PF", stdevAlignScorePF, 
      "PERCENT_ERROR_RATE_PF", errorPF, 
      "SD_PERCENT_ERROR_RATE_PF", errorPFSD]    
      
       hash.each { |k, v| string += "#{k} #{v}"}
       fc_code = "#{fc_name}-#{laneNumber}"
       laneHash1["#{fc_code}-#{readNumber}"] = string
       string = ""
    end
  end
end

#Extract phasing and prephasing results
(doc/:'ExpandedLaneSummary Read').each do|read|
  readNumber = (read/'readNumber').inner_html
  (read/'Lane').each do|lane|
    laneNumber = (lane/'laneNumber').inner_html
    phasingApplied = (lane/'phasingApplied').inner_html
    prephasingApplied = (lane/'prephasingApplied').inner_html
    hash = {}
   
    if(phasingApplied != "")
      hash = ["PERCENT_PHASING", phasingApplied, 
      "PERCENT_PREPHASING", prephasingApplied,
      "RESULTS_PATH", dir]
      
      hash.each { |k, v| string += "#{k} #{v}"}
      fc_code = "#{fc_name}-#{laneNumber}"
      laneHash2["#{fc_code}-#{readNumber}"] = string
      string = ""
    end
  end
end
#end

def hshcmb(h1, h2)
  tmp = Hash.new {|hash, key| hash[key] = " "}
  h1.each {|k,v| tmp[k] << v }
  h2.each {|k,v| tmp[k] << " " + v }
  tmp
end

laneHash = hshcmb(laneHash1, laneHash2)

#laneHash.each { |k, v| puts "perl /data/slx/goats/hgsc_slx/third_party/setIlluminaLaneStatus.pl #{k[0..-3]} ANALYSIS_FINISHED #{v}" }
#laneHash.each { |k, v| puts "#{k[0..-3]}" }

keys = laneHash.keys
maxIdx = keys.size() - 1

for i in 0..maxIdx
  for j in 0..lanesUsedForAnalysis.size
    if(lanesUsedForAnalysis[j] != nil)
      tmpNum = lanesUsedForAnalysis[j].chr
      strToSearch = fc_name + "-" + tmpNum.to_s
      #puts "Searching for : " + strToSearch
        if(keys[i].include? strToSearch) 
          puts "Command to execute : "
#          puts "perl /data/slx/goats/hgsc_slx/third_party/setIlluminaLaneStatus.pl " + keys[i][0..-3] + " ANALYSIS_FINISHED " + "#{laneHash[keys[i]]}"
          cmdToExecute = "perl /data/slx/goats/hgsc_slx/third_party/setIlluminaLaneStatus.pl " + keys[i][0..-3] + " ANALYSIS_FINISHED " + "#{laneHash[keys[i]]}"
          puts cmdToExecute
          system(cmdToExecute)
        end
      end
#  puts "#{laneHash[keys[i]]}"
  end
end
