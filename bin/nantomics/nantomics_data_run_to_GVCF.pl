#!/usr/bin/env perl
# nantomics_data_run_to_GVCF.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Heimdall;
use IO::Dir;

BEGIN {
    ## needed environmental variable
    $ENV{heimdall_config} =
      '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/bin/heimdall.cfg';
}

## make object for record keeping.
my $watch = Heimdall->new( config_file => $ENV{heimdall_config}, );

## Get paths from config
my $process = $watch->config->{nantomics_transfer}->{process};
my $ugpp    = $watch->config->{pipeline}->{UGPp};
my $region  = $watch->config->{pipeline}->{UGP_regions};

## Please see file perltidy.ERR
## Please see file perltidy.ERR
my $cmd = sprintf(
    "nohup %s -cfg nantomics_data_GVCFs.cfg -il %s -ql 60 -e cluster > foo",
      $ugpp, $region
);

say $cmd;
$watch->info_log("$0: pipeline processing started.");
eval { system($cmd) };

if ($@) {
    $watch->error_log("$0: issue execute pipeline process");
}

$watch->info_log("$0: pipeline processing finished.");
