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
    perl analysisData_linker.pl -list_projects 
    perl analysisData_linker.pl -analysis_id A76
    perl analysisData_linker.pl -analysis_id A76 -output_dir CDH_Project

Description:
    Will search the Lustre Repository for GNomEx AnalysisData ids and create a symlink.

    Using the -list_project option will list all available UCGD/UGP projects.
    
Required options:
    -analysis_id    GNomEx AnalysisData id 

Additional options:
    -output_dir     Path and name of the directory to name link. [default: current, -analysis_id].
    -list_projects  Will output table of all current CHPC projects and analysis ids.

\n";

my ( $analysis_id, $list, $output );
GetOptions(
    "analysis_id=s" => \$analysis_id,
    "list_projects" => \$list,
    "output_dir"    => \$output,
);

## make object for record keeping.
my $watch  = Heimdall->new();
my $whoami = `whoami`;
chomp $whoami;

## Default to current.
$output //= '.';

## location of all GNomEx analysis data.
my @data_dir = ('/scratch/ucgd/lustre/Repository/AnalysisData');

## if user just wants to list projects
if ($list) {
    list_projects();
    exit(0);
}

## before moving on check id
die $usage if ( !$analysis_id );

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

sub project_locate {
    my $dir = $File::Find::name;
    say $dir;
}

##------------------------------------------------##

sub analysis_locate {
    no warnings;
    my $dir = $File::Find::name;
    next unless ( $dir =~ /$analysis_id$/ );

    $found = $dir;
}

##------------------------------------------------##

sub list_projects {
    die "$0: analysis_id_name.txt file not found."
      if ( !-e 'analysis_id_name.txt' );

    say "";
    say "| Project Name | Analysis ID |";
    say "| -------------|------------ |";
    system("column -t analysis_id_name.txt");
    say "";
}

##------------------------------------------------##

