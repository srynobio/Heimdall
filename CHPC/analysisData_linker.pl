#!/usr/bin/env perl
# analysisData_linker.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use Getopt::Long;
use File::Find;
use lib '../lib';
use Heimdall;

my $usage = "

Synopsis:
    perl analysisData_linker.pl -analysis_id A76
    perl analysisData_linker.pl -analysis_id A76 -output_dir CDH_Project

Description:
    Will search the Lustre Repository for GNomEx AnalysisData ids and create a symlink.
    
Required options:
    -analysis_id, -ai   GNomEx AnalysisData id 

Additional options:
    -output_dir, -od    Path and name of the directory to name link. [default: current, -analysis_id].

\n";

my ($analysis_id, $output);
GetOptions( 
    "analysis_id|ai=s" => \$analysis_id, 
    "output_dir|od=s"  => \$output,
);
die $usage if ( !$analysis_id );

## make object for record keeping.
my $watch = Heimdall->new();
my $whoami = `whoami`;
chomp $whoami;


## Default to current.
$output //= '.';

## location of all GNomEx analysis data.
my @data_dir = ('/scratch/ucgd/lustre/Repository/AnalysisData');

my $found;
find( { bydepth => 1, no_chdir => 1, wanted => \&analysis_locate }, @data_dir );

if ($found) {
    $watch->info_log("$0: User $whoami linked $analysis_id");
    say "Analysis found...";
    say "Creating symlink to UGP/UCGD analysis.";
    `ln -s $found $output`;
}
else {
    say "$0: [ERROR] - Analysis $analysis_id not found.";
    exit(0);
}

##------------------------------------------------##

sub analysis_locate {
    no warnings;
    my $dir = $File::Find::name;
    next unless ( $dir =~ /$analysis_id$/ );

    $found = $dir;
}

##------------------------------------------------##

