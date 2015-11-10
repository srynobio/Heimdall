use Rex -feature => ['1.0'];
use feature 'say';
use FindBin;
use lib "$FindBin::Bin/lib";
use Heimdall;

BEGIN {
    ## needed environmental variable
    $ENV{heimdall_config} = '/home/srynearson/Heimdall/bin/heimdall.cfg';
}

## make object for record keeping.
my $watch = Heimdall->new( 
    config_file => $ENV{heimdall_config},
);
logging to_file => $watch->log_file;

my $heimdall_ugp       = $watch->config->{main}->{heimdall_ugp_bin};
my $heimdall_chpc      = $watch->config->{main}->{heimdall_chpc_bin};
my $lustre_rsync       = $watch->config->{rsync}->{lustre_rsync};
my $islion_rsync       = $watch->config->{rsync}->{islion_rsync};
my $resource_ugp_path  = $watch->config->{main}->{resource_ugp_path};
my $resource_chpc_path = $watch->config->{main}->{resource_chpc_path};

## Add addition paths to search
path 
    "/uufs/kingspeak.peaks/sys/pkg/slurm/std/bin/",
    "/bin",
    "/sbin",
    "/usr/bin",
    "/usr/sbin",
    "/usr/local/bin",
    "/usr/local/sbin",
    "/usr/pkg/bin",
    "/usr/pkg/sbin";

##------------------------------------------------##
## UGP Server Tasks.
##------------------------------------------------##

desc "UGP: Checks GNomEx for new experiments.";
task experiment_check => sub {
    my $command = 'perl experiment_check.pl';
    run "check",
      command => $command,
      cwd     => $heimdall_ugp;

    ## this task runs on chpc.
    do_task 'upload_experiment_report';
};

##------------------------------------------------##
## CHPC Server Tasks.
##------------------------------------------------##

desc "UGP/CHPC: Will upload the processing_report.txt file to CHPC.";
task 'upload_experiment_report',
  group => 'chpc',
  sub {
    upload "$resource_ugp_path/experiment_report.txt", "$resource_chpc_path";
};

##------------------------------------------------##

<<<<<<< HEAD
desc "CHPC: Check for newly created Repository directories on islion and cp to lustre.";
task 'mirror_directories',
=======
desc
"CHPC: Check for newly created Repository directories on islion and cp to lustre.";
task 'directories_create',
>>>>>>> 9afbe38ec026f3e0e914a38a5cefbf954f333353
  group => 'chpc',
  sub {
    my $command = "perl mirror_directories.pl";
    my $run     = run "dir_check",
      command => $command,
      cwd     => $heimdall_chpc;
};

##------------------------------------------------##

desc "CHPC: Make a symlink of all project in Repository to /Project space.";
task 'link_projects',
  group => 'chpc',
  sub {
    my $command = "perl analysisData_linker.pl -project_link";
    my $run     = run "analysis_link",
      command => $command,
      cwd     => $heimdall_chpc;
};

##------------------------------------------------##

desc "CHPC: rsync ExperimentData from islion to lustre.";
task 'experimentData_rsync_to_lustre',
  group => 'chpc',
  sub {
    my $command = "perl rsync_to_lustre_ExperimentData.pl";
    my $run     = run "rsync_lustre",
      command => $command,
      cwd     => $heimdall_chpc;
};

##------------------------------------------------##

desc "CHPC: rsync AnalysisData from lustre to islion.";
task 'analysisData_rsync_to_islion',
  group => 'chpc',
  sub {
    my $command = "perl rsync_to_islion_AnalysisData.pl";
    my $run     = run "rsync_islion",
      command => $command,
      cwd     => $heimdall_chpc;
};

##------------------------------------------------##
## nantomics
##------------------------------------------------##

desc "CHPC: Watch and control nantomics transfer space.";
task 'nantomics_data_tracker',
  group => 'chpc',
  sub {
    my $command = 'perl nantomics_data_tracker.pl';
    my $run     = run 'nantomics_watch',
      command => $command,
      cwd     => "$heimdall_chpc/nantomics";
};

desc "CHPC: Move BAM files from nantomics/xfer to nantomics/Process_Data.";
task 'nantomics_data_move',
  group => 'chpc',
  sub {
    my $command = 'perl nantomics_data_move.pl';
    my $run     = run 'nantomics_move',
      command => $command,
      cwd     => "$heimdall_chpc/nantomics";
};

desc "CHPC: Run the UGP Pipeline from the nantomics/Process_Data directory.";
task 'nantomics_data_run_to_GVCF',
  group => 'chpc',
  sub {
    my $command = 'perl nantomics_data_run_to_GVCF.pl';
    my $run     = run 'nantomics_run',
      command => $command,
      cwd     => "$heimdall_chpc/nantomics";
};

##------------------------------------------------##
## washu
##------------------------------------------------##

desc "CHPC: Watch and control washu transfer space.";
task 'washu_data_watch',
  group => 'chpc',
  sub {
    my $command = 'perl washu_data_watch.pl';
    my $run     = run 'wash_watch',
      command => $command,
      cwd     => "$heimdall_chpc/washu",
      ;
};

##------------------------------------------------##
## test
##------------------------------------------------##

desc "CHPC: Watch and control test transfer space.";
task 'test_data_watch',
  group => 'chpc',
  sub {
    my $command = 'perl test_data_watch.pl';
    my $run     = run 'test_watch',
      command => $command,
      cwd     => "$heimdall_chpc/test";
};

##------------------------------------------------##

1;

