package Heimdall::CHPC;
use Rex -base;
use Rex::Commands::Rsync;
use strict;
use warnings;
use feature 'say';
use autodie;

## Paths for the Heimdall directory locations on CHPC.
## add to cfg file.
my $chpc_path    = '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/CHPC';
my $lustre_rsync = '/scratch/ucgd/lustre/Repository';
my $islion_rsync = '/uufs/chpc.utah.edu/common/home/ucgdstor/Repository';


##------------------------------------------------##

task directories_create => sub {
    my $command = "perl directories_create.pl";
    my $run     = run "dir_check",
      command => $command,
      cwd     => $chpc_path;
};

##------------------------------------------------##

task link_projects => sub {
    my $command = "perl analysisData_linker.pl -project_link";
    my $run     = run "analysis_link",
      command => $command,
      cwd     => $chpc_path;
};

##------------------------------------------------##

task experimentData_rsync_to_lustre => sub {
    my $command = "perl rsync_to_lustre_ExperimentData.pl";
    my $run     = run "rsync_lustre",
      command => $command,
      cwd     => $chpc_path;
};

##------------------------------------------------##

task analysisData_rsync_to_islion => sub {
    my $command = "perl rsync_to_islion_AnalysisData.pl";
    my $run     = run "rsync_islion",
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

task test_data_watch => sub {
    my $command = 'perl test_data_watch.pl';
    my $run     = run 'data_watch',
      command => $command,
      cwd     => $chpc_path;
};

##------------------------------------------------##

1;

