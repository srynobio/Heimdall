package Heimdall::CHPC;
use Rex -base;
use strict;
use warnings;
use feature 'say';
use autodie;

use Data::Dumper;

## Paths for the Heimdall directory locations on CHPC.
## add to cfg file.
my $chpc_path    = '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/CHPC';
my $lustre_rsync = '/scratch/ucgd/lustre/Repository';
my $islion_rsync = '/uufs/chpc.utah.edu/common/home/ucgdstor/Repository';

##------------------------------------------------##

task directories => sub {
    my $command = "perl directories.pl";
    my $run    = run "dir_check",
      command => $command,
      cwd     => $chpc_path;
};

##------------------------------------------------##

task rsync_to_lustre => sub {
    my $command = "rsync -nvr --partial AnalysisData $islion_rsync/AnalysisData";
    my $run = run "rsync",
      command => $command,
      cwd     => $lustre_rsync;
};

##------------------------------------------------##

task rsync_to_islion => sub {
    my $command = "rsync -nvr --partial ExperimentData $lustre_rsync/ExperimentData";
    my $run = run "rsync",
      command => $command,
      cwd     => $islion_rsync;
};

##------------------------------------------------##

task nantomics_data_watch => sub {
    my $command = 'perl nantomics_data_watch.pl';
    my $run = run 'data_watch', 
        command => $command,
        cwd     => $chpc_path;
};

##------------------------------------------------##



1;

