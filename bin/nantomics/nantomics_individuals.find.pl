#!/usr/bin/env perl
# nantomics_individuals.find.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use File::Find;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Heimdall;

use Rex -feature => ['1.3'];
logging to_file => '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/Heimdall.run.log';

BEGIN {
    $ENV{heimdall_config} = '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/heimdall.cfg';
    if ( ! $ENV{HOSTNAME} =~ /kingspeak/ ) {
        die "Script must be ran on kingspeak (CHPC) server.";
    }
}

## make object for record keeping.
my $heimdall = Heimdall->new( config_file => $ENV{heimdall_config} );

## from config
my $analysis_dir = $heimdall->config->{repository}->{lustre_analysis_repo};
my $process_dir  = $heimdall->config->{nantomics_transfer}->{process};
my $chpc_home    = $heimdall->config->{main}->{chpc_home};

## Global collection
my $project_ids;
my $processed;
open(my $FH, '>>', "$chpc_home/ucgduser.work.txt");

find (\&id_find, $analysis_dir);
find (\&get_processed, $process_dir);

## process data check
if ( ! keys %{$processed} ) {
    Rex::Logger::info('No data found to transfer', 'error');
    exit(0);
}

foreach my $proj (keys %{$project_ids}) {
    foreach my $indiv (@{$project_ids->{$proj}->{ids}}) {

        my @found = grep { $_ =~ /^$indiv.*/ } keys %{$processed};
        next if ( ! @found );

        move_to_project( \@found, $project_ids->{$proj}->{path});
        delete $processed->{$found[0]};
    }
}

map { Rex::Logger::info("File with no home: $_", 'warn') } keys %$processed;
close $FH;

## ----------------------------------------------------------- ##

sub id_find { 
    no warnings;
    next if ( $_ !~ /individuals.txt/ );

    my $full_path = $File::Find::name;
    my @path_parts = split/\//, $full_path;

    my $project_dir = $File::Find::dir;

    open(my $FH, '<', $full_path);
    my @id_list;
    foreach my $peps ( <$FH> ) {
        chomp $peps;
        push @id_list, $peps;
    }
    close $FH;

    $project_ids->{$path_parts[8]}{ids}  = \@id_list;
    $project_ids->{$path_parts[8]}{path} = $project_dir;
}

## ----------------------------------------------------------- ##

sub get_processed {
    no warnings;
    $processed->{$_}++;
};

## ----------------------------------------------------------- ##

sub move_to_project {
    my ( $f_files, $path ) = @_;

    ## only dir used for process to GVCF.
    my $ugp_path = "$path/UGP";
    my @dirs = (
        "$ugp_path/Data/Primary_Data", # 0
        "$ugp_path/Reports/flagstat",  # 1
        "$ugp_path/Reports/stats",     # 2
        "$ugp_path/Reports/fastqc",    # 3
        "$ugp_path/VCF/GVCFs",         # 4 
        "$ugp_path/VCF/WHAM",          # 5
    );

    ## file system check
    map { 
    if ( ! -d $_ ) {
        say "Directory $_ not found";
    }
    } @dirs;

    

    foreach my $file (@{$f_files} ) {
        chomp $file;

        ## doing some moving
        if ( $file =~ /g.vcf$/ ) {
            say $FH "mv $process_dir/$file $dirs[4]"
        }
        elsif ( $file =~ /WHAM/ ) {
            say $FH "mv $process_dir$/file $dirs[5]";
        }
        elsif ( $file =~ /fastqc/ ) {
            say $FH "mv $process_dir/$file $dirs[3]";
        }
        elsif ( $file =~ /stats/ ) {
            say $FH "mv $process_dir/$file $dirs[2]";
        }
        elsif ( $file =~ /flagstat/ ) {
            say $FH "mv $process_dir/$file $dirs[1]";
        }
        elsif ( $file =~ /bam$/ ) {
            say $FH "mv $process_dir/$file $dirs[0]";
        }
    }
}

## ----------------------------------------------------------- ##


