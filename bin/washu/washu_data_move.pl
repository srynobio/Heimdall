#!/usr/bin/env perl
# washu_data_move.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Heimdall;
use IO::File;
use File::Copy qw(move);

## Set up utils object.
my $watch = Heimdall->new(
    config_file => '../../heimdall.cfg',
    log_file    => '../../watch.log'
);

## Get paths from config
my $process           = $watch->config->{washu_transfer}->{process};
my $heimdall_chpc_bin = $watch->config->{UCGD}->{heimdall_chpc_bin};

## Create Filehandles.
my $TXT    = IO::File->new("$heimdall_chpc_bin/experiment_report.txt");
my $DATA   = IO::Dir->new($process);
my $REPORT = IO::File->new("$heimdall_chpc_bin/processed_report.txt");

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
    next if ( !$parts[-1] eq 'new_project' );
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
        $watch->error_log(
            "$0: individual.txt file not found for: $project_space");
    }
}

## clean up.
$TXT->close;
$DATA->close;

## ----------------------------------------------------- ##

sub individuals_find {
    my $project_space = shift;

    my $ID_FILE = IO::File->new("$project_space/individuals.txt");

    my @report;
    foreach my $indv (<$ID_FILE>) {
        chomp $indv;

        ## find file that match individuals.
        my @found = grep { /$indv/ } keys %data_lookup;

        if (@found) {
            individuals_move( \@found, $project_space );

            ## add indiviual and projects
            push @report, [$indv, $project_space];

            ## update log
            $watch->info_log("$0: $project_space updated");
        }
    }

    ## print out moved individuals.
    map { say $REPORT "$_->[0]\t$_->[1]" } @report;

    $ID_FILE->close;
    $REPORT->close;
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
            move( $path_file, $analysis_paths[1] );
        }
        elsif ( $file =~ /stats$/ ) {
            move( $path_file, $analysis_paths[7] );
        }
        elsif ( $file =~ /flagstat$/ ) {
            move( $path_file, $analysis_paths[6] );
        }
        elsif ( $file =~ /(chr|sorted_Dedup)/ ) {
            move( $path_file, $analysis_paths[3] );
        }
        elsif ( $file =~ /bam/ ) {
            move( $path_file, $analysis_paths[2] );
        }
        elsif ( $file =~ /^UGPp/ ) {
            ## first step should not have data here.
        }
        elsif ( $file =~ /gCat/ ) {
            move( $path_file, $analysis_paths[10] );
        }
        elsif ( $file =~ /pdf$/ ) {
            move( $path_file, $analysis_paths[5] );
        }
        elsif ( $file =~ /R$/ ) {
            move( $path_file, $analysis_paths[5] );
        }
        elsif ( $file =~ /fastqc/ ) {
            move( $path_file, $analysis_paths[8] );
        }
        elsif ( $file =~ /gz/ ) {
            move( $path_file, $analysis_paths[3] );
        }
        else {
            move( $path_file, $analysis_paths[3] );
        }
    }
}

## ----------------------------------------------------- ##
