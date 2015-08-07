use Rex -feature => ['1.0'];
# Watch.pl

require Heimdall::CHPC;
require Heimdall::GNomEx;

logging to_file => 'watch.log';

##------------------------------------------------##

desc "Documentation on the use of Heimdall";
task docs => sub {
    print <<"EOD"

This is a place holder. :)

EOD
};

##------------------------------------------------##

desc "GNomEx: Look for newly added experiments.";
task "experiments", sub {
    Heimdall::GNomEx::experiments();
}; 

##------------------------------------------------##

desc "CHPC: Look for newly created experiment directories and copy to lustre";
task "directories", group => 'chpc', sub {
    Heimdall::CHPC::directories();
};

##------------------------------------------------##

desc "CHPC: Run rsync of lustre directory to islion (AnalysisData)";
task 'rync_to_lustre', group => 'chpc', sub {
    Heimdall::CHPC::rsync_to_lustre();
};

##------------------------------------------------##

desc "CHPC: Run rsync of islion directory to lustre (ExperimentData)";
task 'rync_to_islion', group => 'chpc', sub {
    Heimdall::CHPC::rsync_to_islion();
};

##------------------------------------------------##









