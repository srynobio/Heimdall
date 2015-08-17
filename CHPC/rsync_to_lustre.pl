#!/usr/bin/env perl
# rsync_to_lustre.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Heimdall;

my $watch = Heimdall->new();

## add to cfg file.
my $chpc_path    = '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/CHPC';
my $lustre_rsync = '/scratch/ucgd/lustre/Repository';
my $islion_rsync = '/uufs/chpc.utah.edu/common/home/ucgdstor/Repository';

chdir $islion_rsync;

$watch->info_log("rsync of ExperimentData form islion to lustre starting");

my $rsync = "rsync -vr --delete --partial ExperimentData/ $lustre_rsync/ExperimentData";
my $sync = `$rsync`;

$watch->info_log("rsync of ExperimentData from islion to lustre complete");

