#!/usr/bin/env perl
# directories.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Heimdall;
use IO::Dir;

# setup base utils
my $watch = Heimdall->new();

## Set 2015 globals for easy calling.
## add to config later.
my $islion_repo = '/uufs/chpc.utah.edu/common/home/ucgdstor/Repository/AnalysisData/2015';
my $lustre_repo = '/scratch/ucgd/lustre/Repository/AnalysisData/2015';

## Make object and create lookups.
my $iso_dir = IO::Dir->new($islion_repo);
my $lus_dir = IO::Dir->new($lustre_repo);

## Table for lustre
my %lus_lookup;
foreach my $path ( $lus_dir->read ) {
    next if ( $path =~ /(\.|\.\.)/ );
    $lus_lookup{$path}++;
}

## Table for islion
my %isl_lookup;
foreach my $path ( $iso_dir->read ) {
    next if ( $path =~ /(\.|\.\.)/ );
    $isl_lookup{$path}++;
}

## discover any directories which need to be made.
my $record;
foreach my $store ( keys %isl_lookup ) {
    unless ( $lus_lookup{$store} ) {
        my $cmd = "cp -r $islion_repo/$store $lustre_repo/$store";

        #$result = `$cmd`;
        $watch->update_log(
            "directory $islion_repo/$store being copied to $lustre_repo/$store"
        );
        $record++;
        next;
    }
}

## quick status report.
if ( !$record ) {
    $watch->info_log("No directories to copy to lustre AnalysisData");
}
