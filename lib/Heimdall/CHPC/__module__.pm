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
    my $run     = run "dir_check",
      command => $command,
      cwd     => $chpc_path;
};

##------------------------------------------------##

task rsync_to_lustre => sub {
    my $command = "perl rsync_to_lustre.pl";
    my $run     = run "rsync_lustre",
      command => $command,
      cwd     => $chpc_path;
};

##------------------------------------------------##

task rsync_to_islion => {
    my $command = "perl rsync_to_islion.pl";
      my $run   = run "rsync_lustre",
    command => $command,
    cwd     => $chpc_path;
};

##------------------------------------------------##

task nantomics_data_watch => sub {
    my $command = 'perl nantomics_data_watch.pl';
    my $run     = run 'data_watch',
      command => $command,
      cwd     => $chpc_path;
};

##------------------------------------------------##

1;

