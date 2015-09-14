use Rex -feature => ['1.0'];
use feature 'say';
use FindBin;
use lib "$FindBin::Bin/lib";
use Heimdall;

## Set up the utils object.
my $watch = Heimdall->new(
    config_file => 'bin/heimdall.cfg',
    log_file    => 'bin/watch.log'
);
logging to_file => $watch->log_file;

my $heimdall_ugp       = $watch->config->{main}->{heimdall_ugp_bin};
my $heimdall_chpc      = $watch->config->{main}->{heimdall_chpc_bin};
my $lustre_rsync       = $watch->config->{rsync}->{lustre_rsync};
my $islion_rsync       = $watch->config->{rsync}->{islion_rsync};
my $resource_ugp_path  = $watch->config->{main}->{resource_ugp_path};
my $resource_chpc_path = $watch->config->{main}->{resource_chpc_path};

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

desc "CHPC: Check for newly created Repository directories on islion and cp to lustre.";
task 'directories_create',
  group => 'chpc',
  sub {
    my $command = "perl directories_create.pl";
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

desc "CHPC: Watch and control nantomics transfer space.";
task 'nantomics_data_watch',
  group => 'chpc',
  sub {
    my $command = 'perl nantomics_data_watch.pl';
    my $run     = run 'nantomics_watch',
      command => $command,
      cwd     => "$heimdall_chpc/nantomics",
      ;
};

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

