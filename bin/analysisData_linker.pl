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

BEGIN {
    ## needed environmental variable
    $ENV{heimdall_config} =
      '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/bin/heimdall.cfg';
}

my $usage = << "EOU";

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

EOU

my ( $analysis_id, $list, $output, $link );
GetOptions(
    "analysis_id=s" => \$analysis_id,
    "list_projects" => \$list,
    "output_dir=s"  => \$output,
    "project_link"  => \$link,
);

## make object for record keeping.
my $watch = Heimdall->new( config_file => $ENV{heimdall_config}, );
my $whoami = `whoami`;
chomp $whoami;

# Get paths from config file.
my @data_dir      = ( $watch->config->{main}->{lustre_data} );
my $lustre_path   = $watch->config->{main}->{lustre_path};
my $project_path  = $watch->config->{main}->{project_path};
my $resource_path = $watch->config->{main}->{resource_chpc_path};

## Default to current.
$output //= '.';

## Check and run alternate tasks if called then end.
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

sub analysis_locate {
    no warnings;
    my $dir = $File::Find::name;
    next unless ( $dir =~ /$analysis_id$/ );

    $found = $dir;
}

##------------------------------------------------##

sub list_projects {

    ## add to cfg file.
    my $id_name_file = "$resource_path/experiment_report.txt";
    die "$0: experiment_report.txt file not found." if ( !-e $id_name_file );

    say "";
    say "|  Analysis ID | Project Path | Experiment ID | Status |";
    say "| -------------|-------------- | ------------- | ------ |";
    system("column -t $id_name_file");
    say "";
}

##------------------------------------------------##

sub project_analysis_link {
    my $FH = IO::File->new("$resource_path/experiment_report.txt");

    $watch->info_log("$0: $whoami updating symlinks in /Project space.");

    chdir $project_path;
    foreach my $project (<$FH>) {
        chomp $project;
        my @parts      = split /\t/, $project;
        my @path_parts = split /\//, $parts[1];

        symlink( $parts[1], $path_parts[8] );
    }
}

##------------------------------------------------##

