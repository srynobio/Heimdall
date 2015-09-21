#!/usr/bin/env perl
# nantomics_data_move.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Heimdall;
use IO::Dir;
use File::Copy qw(move);

BEGIN {
    ## needed environmental variable
    $ENV{heimdall_config} =
      '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/bin/heimdall.cfg';
}

## make object for record keeping.
my $watch = Heimdall->new( config_file => $ENV{heimdall_config}, );

## Get paths from config
my $process                = $watch->config->{nantomics_transfer}->{process};
my $heimdall_chpc_resource = $watch->config->{main}->{resource_chpc_path};

## Create Filehandles.
open( my $TXT,    '<',  "$heimdall_chpc_resource/experiment_report.txt" );
open( my $REPORT, '>>', "$heimdall_chpc_resource/processed_report.txt" );
my $DATA = IO::Dir->new($process);

## create lookup of current /Process_Data collection.
my %data_lookup;
foreach my $file ( $DATA->read ) {
    chomp $file;
    $data_lookup{$file}++;
}

## collect projects currently processing.
my @dirs;
foreach my $proj_file (<$TXT>) {
    chomp $proj_file;

    my @parts = split /\t/, $proj_file;

    ## exit out if no data set to be processed.
    next unless ( $parts[-1] eq 'new_project' );
    push @dirs, $parts[1];
}

## exit if no work
if ( !@dirs ) {
    $watch->info_log("$0: No data which needs processing found.");
    exit(0);
}

## collect individual.txt file.
foreach my $project_space (@dirs) {
    chomp $project_space;

    if ( -e "$project_space/individuals.txt" ) {
        individuals_find($project_space);
    }
    else {
        $watch->info_log(
            "$0: individual.txt file not found for: $project_space");
    }
}

## clean up.
close $TXT;
close $REPORT;
$DATA->close;

## ----------------------------------------------------- ##

sub individuals_find {
    my $project_space = shift;

    open( my $ID_FILE, '<', "$project_space/individuals.txt" );

    my @report;
    foreach my $indv (<$ID_FILE>) {
        chomp $indv;

        ## find file that match individuals.
        my @found = grep { $_ =~ /$indv/ } keys %data_lookup;

        if (@found) {
            individuals_move( \@found, $project_space );

            ## add indiviual and projects
            push @report, [ $indv, $project_space ];

            ## update log
            $watch->info_log("$0: $project_space updated");
        }
    }

    ## print out moved individuals.
    map { say $REPORT "$_->[0]\t$_->[1]" } @report;

    close $ID_FILE;
}

## ----------------------------------------------------- ##

sub individuals_move {
    my ( $files, $project_space ) = @_;

    my @analysis_paths = (
        "$project_space/UGP/Analysis",
        "$project_space/UGP/Data/PolishedBams",
        "$project_space/UGP/Data/Primary_Data",
        "$project_space/UGP/Intermediate_Files",
        "$project_space/UGP/QC",
        "$project_space/UGP/Reports",
        "$project_space/UGP/Reports/flagstat",
        "$project_space/UGP/Reports/stats",
        "$project_space/UGP/Reports/fastqc",
        "$project_space/UGP/VCF/Complete",
        "$project_space/UGP/VCF/GVCFs",
        "$project_space/UGP/VCF",
    );

    ## Super mover
    ## Maintain order
    foreach my $file ( @{$files} ) {
        chomp $file;

        ## Make full path to file.
        my $path_file = "$process/$file";

        if ( $file =~ /_recal.ba/ ) {
            move( $path_file, "$analysis_paths[1]/$file" );
        }
        elsif ( $file =~ /stats$/ ) {
            move( $path_file, "$analysis_paths[7]/$file" );
        }
        elsif ( $file =~ /flagstat$/ ) {
            move( $path_file, "$analysis_paths[6]/$file" );
        }
        elsif ( $file =~ /(chr|sorted_Dedup)/ ) {
            move( $path_file, "$analysis_paths[3]/$file" );
        }
        elsif ( $file =~ /bam/ ) {
            move( $path_file, "$analysis_paths[2]/$file" );
        }
        elsif ( $file =~ /^UGPp/ ) {
            ## first step should not have data here.
        }
        elsif ( $file =~ /gCat/ ) {
            move( $path_file, "$analysis_paths[10]/$file" );
        }
        elsif ( $file =~ /pdf$/ ) {
            move( $path_file, "$analysis_paths[5]/$file" );
        }
        elsif ( $file =~ /R$/ ) {
            move( $path_file, "$analysis_paths[5]/$file" );
        }
        elsif ( $file =~ /fastqc/ ) {
            move( $path_file, "$analysis_paths[8]/$file" );
        }
        elsif ( $file =~ /gz/ ) {
            move( $path_file, "$analysis_paths[3]/$file" );
        }
        else {
            move( $path_file, "$analysis_paths[3]/$file" );
        }
    }
}

## ----------------------------------------------------- ##

