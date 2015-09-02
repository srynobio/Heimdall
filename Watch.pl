use Rex -feature => ['1.0'];
# Watch.pl
use FindBin;
use lib "$FindBin::Bin/../lib";
use Heimdall;
require Heimdall::CHPC;
require Heimdall::UGP;

my $watch         = Heimdall->new();
my $heimdall_chpc = $watch->config->{UCGD}->{heimdall_chpc};

logging to_file => 'watch.log';

##------------------------------------------------##

desc "Documentation on the use of Heimdall";
task docs => sub {
    print <<"EOD"

This is a place holder. :)

EOD
};

##------------------------------------------------##

desc "UGP: Look for newly added experiments.";
task "experiment_check", sub {
    Heimdall::UGP::experiment_check();
};

##------------------------------------------------##

desc "CHPC: Look for newly created experiment directories and copy to lustre";
task "directories_create",
  group => 'chpc',
  sub {
    Heimdall::CHPC::directories_create();
  };

##------------------------------------------------##

desc "CHPC: Will make AnalysisData links in lustre /Project space.";
task 'link_projects',
  group => 'chpc',
  sub {
    Heimdall::CHPC::link_projects();
  };

##------------------------------------------------##

desc "CHPC: Run rsync of islion directory to lustre (ExperimentData)";
task 'experimentData_rsync_to_lustre',
  group => 'chpc',
  sub {
    Heimdall::CHPC::experimentData_rsync_to_lustre();
  };

##------------------------------------------------##

desc "CHPC: Run rsync of lustre directory to islion (AnalysisData).";
task 'analysisData_rsync_to_islion',
  group => 'chpc',
  sub {
    Heimdall::CHPC::analysisData_rsync_to_islion();
  };

##------------------------------------------------##

desc "CHPC: Check the status of the nantomics xfer directory.";
task 'nantomics_data_watch',
  group => 'chpc',
  sub {
    Heimdall::CHPC::nantomics_data_watch();
  };

##------------------------------------------------##

desc "CHPC: Check the status of the test xfer directory.";
task 'test_data_watch',
  group => 'chpc',
  sub {
    Heimdall::CHPC::test_data_watch();
  };

##------------------------------------------------##

desc "UGP/CHPC: Will upload the current analysis_id_name.txt file to CHPC."
  . " Running experiment will do this automatically.";
task "analysis_info_upload",
  group => 'chpc',
  sub {
    upload "UGP/analysis_id_name.txt", "$heimdall_chpc";
  };

## ------------------------------------------------------------ ##

