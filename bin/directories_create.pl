#!/usr/bin/env perl
# directories_create.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Heimdall;
use File::Find;
use File::Path;

BEGIN {
    ## needed environmental variable
    $ENV{heimdall_config} =
      '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/bin/heimdall.cfg';
}

## make object for record keeping.
my $watch = Heimdall->new( config_file => $ENV{heimdall_config}, );

## Get needed path info.
my @islion_analysis_path = ( $watch->config->{repository}->{islion_repo} );
my @lustre_analysis_path = ( $watch->config->{repository}->{lustre_repo} );

## make shortend paths for later
( my $islion_repo = $islion_analysis_path[0] ) =~ s/(.*)AnalysisData/$1/;
( my $lustre_repo = $lustre_analysis_path[0] ) =~ s/(.*)AnalysisData/$1/;

my %lustre_directories;
my %islion_directories;

## islion find.
find(
    {
        wanted   => \&islion_build_lookup,
        bydepth  => 1,
        no_chdir => 1,
    },
    @islion_analysis_path
);

## lustre find.
find(
    {
        wanted   => \&lustre_build_lookup,
        bydepth  => 1,
        no_chdir => 1,
    },
    @lustre_analysis_path
);
## only work with difference.
my $record;
for my $dirs ( keys %islion_directories ) {
    chomp $dirs;
    next if ( $lustre_directories{$dirs} );

    $record++;

    ## remove project name and UGP from the path.
    ( my $new_dirs = $dirs ) =~ s/(.*)\/(.*)\/UGP$/$1/;

    ## remove UGP form original islion dir
    ( my $original_dirs = $dirs ) =~ s/UGP$//g;

    ## make path
    mkpath("$lustre_repo$new_dirs");

    ## cp from islion to lustre
    my $cmd = sprintf( "cp -r %s%s %s%s",
        $islion_repo, $original_dirs, $lustre_repo, $new_dirs );
    $watch->update_log("Directory $new_dirs being copied to lustre");

    system($cmd);
    if ( $? == -1 ) {
        $watch->error_log("Directory $new_dirs could not be created.");
    }
}

## quick status report.
if ( !$record ) {
    $watch->info_log("No directories to copy to lustre AnalysisData");
}

## ------------------------------------- ##

sub islion_build_lookup {

    my $dir = $File::Find::dir;

    if ( $dir =~ /UGP$/ ) {
        ## isolate only shared paths
        ( my $shared_struct = $dir ) =~ s/(.*)(AnalysisData)(.*)$/$2$3/;
        $islion_directories{$shared_struct}++;
    }
}

## ------------------------------------- ##

sub lustre_build_lookup {

    my $dir = $File::Find::dir;

    if ( $dir =~ /UGP$/ ) {
        ## isolate only shared paths
        ( my $shared_struct = $dir ) =~ s/(.*)(AnalysisData)(.*)$/$2$3/;
        $lustre_directories{$shared_struct}++;
    }
}

## ------------------------------------- ##
