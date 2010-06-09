#!/usr/bin/perl -w

##!/data/pipeline/code/production/bin/x86_64-linux/perl -w

use strict;
use LWP;

if( @ARGV % 1) {
print "usage: $0 lane_barcode \n";
exit;
}


my $ncbiURL ="http://10.10.53.190:8080/ngenlims/getAnalysisPreData.jsp?";
my $paraStr = "lane_barcode=" . $ARGV[0];

$ncbiURL="$ncbiURL$paraStr";
print "$ncbiURL\n";

my $ua = LWP::UserAgent->new;
my $response=$ua->get($ncbiURL);


if(not $response->is_success ) {print "Error: Cannot connect\n"; exit(0);}

my $textStr= $response->content;
$textStr=~/^\s*(.+)\s*$/;
$textStr=$1;
print "$textStr\n";
