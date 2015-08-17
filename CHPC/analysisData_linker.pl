#!/usr/bin/env perl
# analysisData_linker.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use Getopt::Long;
use File::Find;
use IO::File;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Heimdall;


## add to cfg file
## location of all GNomEx analysis data.
my @data_dir = ('/scratch/ucgd/lustre/Repository/AnalysisData');
my $lustre_path = '/scratch/ucgd/lustre';
my $project_path = '/scratch/ucgd/lustre/Projects';

my $usage = "

Synopsis:
    perl analysisData_linker.pl -list_projects 
    perl analysisData_linker.pl -analysis_id A76
    perl analysisData_linker.pl -analysis_id A76 -output_dir CDH_Project
    perl analysisData_linker.pl -project_link

Description:
    Will search the Lustre Repository for GNomEx AnalysisData ids and create a symlink.

    Using the -list_project option will list all available UCGD/UGP projects and there status.
    
Required options:
    -analysis_id    GNomEx AnalysisData id 

Additional options:
    -output_dir     Path and name of the directory to name link. [default: current, -analysis_id].
    -list_projects  Will output table of all current CHPC projects and analysis ids.
    -project_link   Will take all current UGP-GNomEx projects from -list_projects and create a symlink to each.

\n";

my ( $analysis_id, $list, $output, $link );
GetOptions(
    "analysis_id=s" => \$analysis_id,
    "list_projects" => \$list,
    "output_dir=s"    => \$output,
    "project_link"  => \$link,
);

## make object for record keeping.
my $watch  = Heimdall->new();
my $whoami = `whoami`;
chomp $whoami;

## Default to current.
$output //= '.';

## Check and run alternate tasks if call then end.
if ($list) {
    list_projects();
    exit(0);
}
if ($link) {
    project_analysis_link();
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
      if ( ! -e 'analysis_id_name.txt' );

    say "";
    say "|  Analysis ID | Analysis Path | Experiment ID | Status |";
    say "| -------------|-------------- | ------------- | ------ |";
    system("column -t analysis_id_name.txt");
    say "";
}

##------------------------------------------------##

sub project_analysis_link {
    my $FH = IO::File->new('analysis_id_name.txt');

    chdir $project_path;
    foreach my $project (<$FH>) {
        chomp $project;
        my @parts = split /\t/, $project;

        my @path_data = split /\//, $parts[1];
        #say "ln -s $lustre_path$parts[1] $path_data[-1]";
        `ln -s $lustre_path$parts[1] $path_data[-1]`;
    }
}

##------------------------------------------------##

