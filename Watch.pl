use Rex -feature => ['1.0'];
use feature 'say';
use FindBin;
use lib "$FindBin::Bin/../lib";
use Heimdall;

## Set up the utils object.
my $watch = Heimdall->new(
    config_file => 'heimdall.cfg',
    log_file    => 'watch.log'
);
logging to_file => 'watch.log';

my $heimdall_ugp  = $watch->config->{UCGD}->{heimdall_ugp_bin};
my $heimdall_chpc = $watch->config->{UCGD}->{heimdall_chpc_bin};
my $lustre_rsync  = $watch->config->{rsync}->{lustre_rsync};
my $islion_rsync  = $watch->config->{rsync}->{islion_rsync};

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
    do_task 'upload_processing_report';
};

##------------------------------------------------##
## CHPC Server Tasks.
##------------------------------------------------##

desc "UGP/CHPC: Will upload the processing_report.txt file to CHPC.";
task 'upload_processing_report',
  group => 'chpc',
  sub {
    upload "bin/processing_report.txt", "$heimdall_chpc";
};

##------------------------------------------------##

task 'directories_create',
  group => 'chpc',
  sub {
    my $command = "perl directories_create.pl";
    my $run     = run "dir_check",
      command => $command,
      cwd     => $heimdall_chpc;
};

##------------------------------------------------##

task 'link_projects',
  group => 'chpc',
  sub {
    my $command = "perl analysisData_linker.pl -project_link";
    my $run     = run "analysis_link",
      command => $command,
      cwd     => $heimdall_chpc;
};

##------------------------------------------------##

task 'experimentData_rsync_to_lustre',
  group => 'chpc',
  sub {
    my $command = "perl rsync_to_lustre_ExperimentData.pl";
    my $run     = run "rsync_lustre",
      command => $command,
      cwd     => $heimdall_chpc;
};

##------------------------------------------------##

task 'analysisData_rsync_to_islion',
  group => 'chpc',
  sub {
    my $command = "perl rsync_to_islion_AnalysisData.pl";
    my $run     = run "rsync_islion",
      command => $command,
      cwd     => $heimdall_chpc;
};

##------------------------------------------------##

task 'nantomics_data_watch',
  group => 'chpc',
  sub {
    my $command = 'perl nantomics_data_watch.pl';
    my $run     = run 'data_watch',
      command => $command,
      cwd     => $heimdall_chpc;
};

##------------------------------------------------##

task 'test_data_watch',
  group => 'chpc',
  sub {
    my $command = 'perl test_data_watch.pl';
    my $run     = run 'data_watch',
      command => $command,
      cwd     => $heimdall_chpc;
};

##------------------------------------------------##

