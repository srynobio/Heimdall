#!/usr/bin/env perl
# rsync_to_lustre_ExperimentData.pl
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

my $lustre_experiment = $lustre_rsync . "/ExperimentData";
my $islion_experiment = $islion_rsync . "/ExperimentData";

## quick trick to get directory list.
my @directory_list = `ls $islion_experiment`;

my @rsync_cmds;
for my $year (@directory_list) {
    chomp $year;

    my $lustre_path = $lustre_experiment . "/$year";
    my $islion_path = $islion_experiment . "/$year";

    opendir( my $PATH, $islion_path );
    while ( my $project = readdir($PATH) ) {
        next if ( $project =~ /(\.|\.\.)/ );
        my $rsync =
            "rsync -vr --size-only --partial $islion_path/$project/ $lustre_path/$project";
        push @rsync_cmds, $rsync;
    }
}

$watch->info_log("rsync of ExperimentData from islion to lustre starting");

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

$watch->info_log("rsync of ExperimentData from islion to lustre finished.");

