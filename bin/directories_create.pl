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

BEGIN {
    ## needed environmental variable
    $ENV{heimdall_config} =
      '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/bin/heimdall.cfg';
}

## make object for record keeping.
my $watch = Heimdall->new( config_file => $ENV{heimdall_config}, );

## Get needed path info.
my @islion_repo = ( $watch->config->{repository}->{islion_repo} );
my @lustre_repo = ( $watch->config->{repository}->{lustre_repo} );

## make shortend paths for later
( my $islion = $islion_repo[0] ) =~ s/(.*)AnalysisData/$1/;
( my $lustre = $lustre_repo[0] ) =~ s/(.*)AnalysisData/$1/;

my %lustre_directories;
my %islion_directories;

## islion find.
find(
    {
        wanted   => \&islion_build_lookup,
        bydepth  => 1,
        no_chdir => 1,
    },
    @islion_repo
);

## lustre find.
find(
    {
        wanted   => \&lustre_build_lookup,
        bydepth  => 1,
        no_chdir => 1,
    },
    @lustre_repo
);

## only work with difference.
my $record;
for my $dirs ( keys %islion_directories ) {
    chomp $dirs;
    next if ( $lustre_directories{$dirs} );

    $record++;
    ## cp from islion to lustre
    my $cmd = sprintf( "cp -r %s%s %s%s", $islion, $dirs, $lustre, $dirs );
    $watch->update_log( "Directory $dirs being copied to lustre" );

    system($cmd);
    if ( $? == -1 ) {
        $watch->error_log("Directory $dirs could not be created.");
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
