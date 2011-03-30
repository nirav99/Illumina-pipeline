#!/usr/bin/perl -w

##!/data/pipeline/code/production/bin/x86_64-linux/perl -w

# EXAMPLE to Run: "perl ./setIlluminaCaptureResults.pl 30F4EAAXX-1 CAPTURE_FINISHED BUFFER_ALIGNED_READS 172160 PERCENT_BUFFER_ALIGNED_READS 47434 TARGET_ALIGNED_READS 5582" etc and so forth....

#INPUT:
# lane_barcode
# - barcode of the lane, which is the flowcell barcode plus the addition of the lane number (ie, if the flowcell is FC3034FAAXX and the lane is "lane 2", then the lane barcode is FC3034FAAXX-2).

#status:

# - CAPTURE_FINISHED
# The Following are name that you should accompany with values:
# - BUFFER_ALIGNED_READS
# - PERCENT_BUFFER_ALIGNED_READS
# - TARGET_ALIGNED_READS
# - PERCENT_TARGET_ALIGNED_READS
# - TARGETS_HIT
# - PERCENT_TARGETS_HIT
# - TARGET_BUFFERS_HIT
# - PER_TARGET_BUFFERS_HITS
# - TOTAL_TARGETS
# - HIGH_COVERAGE_NON_TARGET_HITS
# - BASES_ON_TARGET
# - BASES_ON_BUFFER
# - 1_COVERAGE_BASES
# - PER_1_COVERAGE_BASES
# - 4_COVERAGE_BASES
# - PER_4_COVERAGE_BASES
# - 10_COVERAGE_BASES
# - PER_10_COVERAGE_BASES
# - 20_COVERAGE_BASES
# - PER_20_COVERAGE_BASES
# - 40_COVERAGE_BASES
# - PER_40_COVERAGE_BASES
# - RESULTS_PATH

use strict;
use LWP;

if( @ARGV % 2 ) {
print "usage: $0 lane_barcode status <name/value pairs>\n";
exit;
}

my $ncbiURL ="http://lims-1.hgsc.bcm.tmc.edu/ngenlims/setIlluminaCaptureResults.jsp?";
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
$textStr=~ s/\s+$//;
print "$textStr\n";