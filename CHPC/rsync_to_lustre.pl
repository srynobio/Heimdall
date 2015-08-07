#!/usr/bin/env perl
# rsync_to_lustre.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use lib '../lib';
use Heimdall;

my $watch = Heimdall->new();

## add to cfg file.
my $chpc_path    = '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/CHPC';
my $lustre_rsync = '/scratch/ucgd/lustre/Repository';
my $islion_rsync = '/uufs/chpc.utah.edu/common/home/ucgdstor/Repository';


$watch->info_log("rsync of ExperimentData form islion to lustre starting");

chdir $islion_rsync;
my $rsync = "rsync -nvr --partial ExperimentData $lustre_rsync/ExperimentData";
my $sync = `$rsync`;

$watch->info_log("rsync of ExperimentData from islion to lustre complete");

