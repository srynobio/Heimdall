#!/usr/bin/env perl
# directories_create.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Heimdall;

use File::Find;

use IO::Dir;

BEGIN {
    ## needed environmental variable
    $ENV{heimdall_config} = '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/bin/heimdall.cfg';
}

## make object for record keeping.
my $watch = Heimdall->new( 
    config_file => $ENV{heimdall_config},
);

## Get paths from config file.
my $islion_repo = $watch->config->{repository}->{islion_repo};
#my $lustre_repo = $watch->config->{repository}->{lustre_repo};

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
        `$cmd`;

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
