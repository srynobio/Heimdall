#!/usr/bin/env perl
# rsync_to_islion_AnalysisData.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Heimdall;
use File::Find;
use Parallel::ForkManager;

BEGIN {
    ## needed environmental variable
    $ENV{heimdall_config} =
      '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/bin/heimdall.cfg';
}

## make object for record keeping.
my $watch = Heimdall->new( config_file => $ENV{heimdall_config}, );

## Get paths from config file.
my $lustre_rsync = $watch->config->{rsync}->{lustre_rsync};
my $islion_rsync = $watch->config->{rsync}->{islion_rsync};

my $lustre_analysis = $lustre_rsync . "/AnalysisData";
my $islion_analysis = $islion_rsync . "/AnalysisData";

## quick trick to get directory list.
my @directory_list = `ls $lustre_analysis`;

my @rsync_cmds;
for my $year (@directory_list) {
    chomp $year;

    my $lustre_path = $lustre_analysis . "/$year";
    my $islion_path = $islion_analysis . "/$year";

    opendir( my $PATH, $lustre_path );
    while ( my $project = readdir($PATH) ) {
        next if ( $project =~ /(\.|\.\.)/ );
        my $rsync =
            "rsync -vr --size-only --partial $lustre_path/$project/ $islion_path/$project";
        push @rsync_cmds, $rsync;
    }
}

$watch->info_log("rsync of AnalysisData from lustre to islion starting");

## set up cpu info
my $pm = Parallel::ForkManager->new('10');
for my $cmd (@rsync_cmds) {
    $pm->start and next;
    system($cmd);
    if ($@) {
        $watch->error_log("$0 rsync command failed $@");
    }
    $pm->finish;
}
$pm->wait_all_children;

$watch->info_log("rsync of AnalysisData from lustre to islion finished.");

