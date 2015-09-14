#!/usr/bin/env perl
# process_to_GVCFs.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Heimdall;
use IO::Dir;

my $watch = Heimdall->new(
    config_file => '../heimdall.cfg',
    log_file    => '../watch.log'
);

## Get paths from config file.
my $path               = $watch->config->{test_transfer}->{path};
my $process            = $watch->config->{test_transfer}->{process};
my $xfer               = $watch->config->{test_transfer}->{xfer};
my $config             = $watch->config->{test_transfer}->{pipeline_config};
my $region             = $watch->config->{test_transfer}->{pipeline_region};
my $ugp_p              = $watch->config->{main}->{UGPp};
my $resource_chpc_path = $watch->config->{main}->{resource_chpc_path};

my $PROS = IO::Dir->new($process);
my @bams;
foreach my $bam ( $PROS->read ) {
    chomp $bam;

    next unless ( $bam =~ /bam$/ );
    push @bams, $bam;
}

if ( !@bams ) {
    $watch->info_log("$0: No BAMs found in $process");
    exit(0);
}

## write processing files to process_report.txt
open( my $FH, '>', "$resource_chpc_path/process_report.txt" );
map { say $FH $_ } @bams;

## write each file to process_report
map { $watch->info_log("$0: starting pipeline analysis on $_") } @bams;

## start the pipeline if found.
my $cmd = "$ugp_p -cfg $config -il $region --run";
$watch->info_log("$0: Running command: $cmd");

system($cmd);

$PROS->close;
$FH->close;
