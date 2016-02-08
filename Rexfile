use Rex -feature => ['1.3'];
use feature 'say';

logging to_file => "Heimdall.run.log";

require UGP::Tasks;
require CHPC::Tasks;


BEGIN {
    if ( $ENV{HOSTNAME} ne 'ugp.chpc.utah.edu' ) {
        die "Heimdall designed to run on ugp.chpc.utah.edu";
    }
}

1;
