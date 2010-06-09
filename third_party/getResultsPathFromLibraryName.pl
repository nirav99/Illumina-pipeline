#!/usr/bin/perl -w

##!/data/pipeline/code/production/bin/x86_64-linux/perl -w

#EXAMPLE to Run: "perl ./getResultsPathFromLibraryName.pl IWG_LVAR.00_001pA"

use strict;
use LWP;

if( @ARGV % 1) {
print "usage: $0 libraryName \n";
exit;
}

my $ncbiURL ="http://gen2.hgsc.bcm.tmc.edu/ngenlims/getResultsPathFromLibraryName.jsp?";
my $paraStr = "libraryName=" . $ARGV[0];

$ncbiURL="$ncbiURL$paraStr";
#print "$ncbiURL\n";

my $ua = LWP::UserAgent->new;
my $response=$ua->get($ncbiURL);

if(not $response->is_success ) {print "Error: Cannot connect\n"; exit(0);}

my $textStr= $response->content;
$textStr=~ s/\s+$//;
print "$textStr\n";
