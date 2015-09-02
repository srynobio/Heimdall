#!/usr/bin/env perl
# rsync_to_islion_AnalysisData.pl
# This script rsyncs AnalysisData from
# lustre (data processing ) to islion (GNomEx version).
use strict;
use warnings;
use feature 'say';
use autodie;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Heimdall;

my $watch = Heimdall->new();

## Get paths from config file.
##my $heimdall_path = $watch->config->{UCGD}->{heimdall_path};
my $lustre_rsync  = $watch->config->{rsync}->{lustre_rsync};
my $islion_rsync  = $watch->config->{rsync}->{islion_rsync};

#my $heimdall_path    = '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/CHPC';
#my $lustre_rsync = '/scratch/ucgd/lustre/Repository';
#my $islion_rsync = '/uufs/chpc.utah.edu/common/home/ucgdstor/Repository';

chdir $lustre_rsync;

$watch->info_log("rsync of AnalysisData from lustre to islion starting");

#my $rsync = "rsync -nvr --partial AnalysisData $islion_rsync/AnalysisData";
my $rsync = "rsync -vr --partial AnalysisData $islion_rsync/AnalysisData";
my $sync = `$rsync`;

$watch->info_log("rsync of AnalysisData from lustre to islion complete.");

