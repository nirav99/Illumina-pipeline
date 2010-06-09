#!/usr/bin/perl -w

##!/data/pipeline/code/production/bin/x86_64-linux/perl -w

# EXAMPLE to Run: "perl ./setIlluminaLaneStatus.pl 30F4EAAXX-1 REFERENCE_GENOME_SET PATH /data/illumina/datadirectory"
# (or) "perl ./setIlluminaLaneStatus.pl 30F4EAAXX-1 ANALYSIS_FINISHED LANE_YIELD_KBASES 172160 CLUSTERS_RAW 47434 SD_CLUSTERS_RAW 5582" etc and so forth....

#INPUT:
# lane_barcode
# - barcode of the lane, which is the flowcell barcode plus the addition of the lane number (ie, if the flowcell is FC3034FAAXX and the lane is "lane 2", then the lane barcode is FC3034FAAXX-2).

#status:
# - REFERENCE_GENOME_SET
# - PATH with a value.

# - ANALYSIS FINISHED
# The Following are name that you should accompany with values:
# - LANE_YIELD_KBASES
# - CLUSTERS_RAW
# - SD_CLUSTERS_RAW
# - CLUSTERS_PF
# - FIRST_CYCLE_INT_PF
# - SD_FIRST_CYCLE_INT_PF
# - PERCENT_INTENSITY_AFTER_20_CYCLES_PF
# - SD_PERCENT_INTENSITY_AFTER_20_CYCLES_PF
# - PERCENT_PF_CLUSTERS
# - SD_PERCENT_PF_CLUSTERS
# - PERCENT_ALIGN_PF
# - SD_PERCENT_ALIGN_PF
# - ALIGNMENT_SCORE_PF
# - SD_ALIGNMENT_SCORE_PF
# - PERCENT_ERROR_RATE_PF
# - SD_PERCENT_ERROR_RATE_PF
# - PERCENT_PHASING
# - PERCENT_PREPHASING
# - RESULTS_PATH

use strict;
use LWP;

if( @ARGV % 2 ) {
print "usage: $0 lane_barcode status <name/value pairs>\n";
exit;
}

my $ncbiURL ="http://gen2.hgsc.bcm.tmc.edu/ngenlims/setIlluminaLaneStatus.jsp?";
my $paraStr = "lane_barcode=" . $ARGV[0]."&status=".$ARGV[1];

my $i;
my $index=1;
for($i=2; $i<@ARGV;$i +=2){
    $paraStr .= "&key$index=" . $ARGV[$i] ."&value$index=".$ARGV[$i+1];
    $index++;
}

$ncbiURL="$ncbiURL$paraStr";

my $ua = LWP::UserAgent->new;
my $response=$ua->get($ncbiURL);

if(not $response->is_success ) {print "Error: Cannot connect\n"; exit(-1);}

my $textStr= $response->content;
$textStr=~/^\s*(.+)\s*$/;
$textStr=$1;
print "$textStr\n";
