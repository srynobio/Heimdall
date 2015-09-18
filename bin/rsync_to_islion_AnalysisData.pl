#!/usr/bin/env perl
# rsync_to_islion_AnalysisData.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Heimdall;

BEGIN {
    ## needed environmental variable
    $ENV{heimdall_config} = '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/bin/heimdall.cfg';
}

## make object for record keeping.
my $watch = Heimdall->new( 
    config_file => $ENV{heimdall_config},
);

## Get paths from config file.
my $lustre_rsync = $watch->config->{rsync}->{lustre_rsync};
my $islion_rsync = $watch->config->{rsync}->{islion_rsync};

$watch->info_log("rsync of AnalysisData from lustre to islion starting");
chdir $lustre_rsync;

my $rsync = "rsync -nvr --partial AnalysisData $islion_rsync";
my $sync  = system("$rsync");

