#!/usr/bin/perl

use strict;

my $inFile = $ARGV[0];
my $ouFile = $ARGV[1];

open(inFP,"<$inFile");
my @in = <inFP>;
my $inLen = scalar(@in);

open(ouFP,">$ouFile");

my $cnt = 0;
foreach my $lion (@in) {

  if ($lion =~ />/) {
    print ouFP "NNNNNNNNNN";
  } else { 
    print ouFP $lion;
  }

}

