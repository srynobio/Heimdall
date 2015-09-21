#!/usr/bin/env perl
# nantomics_data_watch.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Heimdall;
use IO::Dir;

BEGIN {
    ## needed environmental variable
    $ENV{heimdall_config} = '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/bin/heimdall.cfg';
}

## make object for record keeping.
my $watch = Heimdall->new( 
    config_file => $ENV{heimdall_config},
);

## Get paths from config file.
my $path    = $watch->config->{nantomics_transfer}->{path};
my $process = $watch->config->{nantomics_transfer}->{process};
my $xfer    = $watch->config->{nantomics_transfer}->{xfer};

## quick check.
unless ( -e $path and -e $process and -e $xfer ) {
    $watch->error_log(
        "$0: One or more directories not found in $path [process, xfer]");
    exit(0);
}

## check for open fileshandles.
my @xfers = `lsof +D $xfer`;
chomp @xfers;
$watch->info_log("$0: No current transfering files ") if ( !@xfers );

my %tranf_lookup;
if (@xfers) {
    foreach my $xfer (@xfers) {
        chomp $xfer;
        next unless ( $xfer =~ /bam$/ );
        my @lsof  = split /\s/, $xfer;
        my @parts = split /\//, $lsof[-1];
        $tranf_lookup{ $parts[-1] }++;
    }
}

## collect all BAM files in xfer.
my $XFER = IO::Dir->new($xfer);
my @bams;
foreach my $bam ( $XFER->read ) {
    next unless $bam =~ /bam$/;
    chomp $bam;
    push @bams, $bam;
}

## second checks
if ( !@bams ) {
    $watch->info_log(
        "$0: No complete non-transfering BAM files found in $xfer");
    exit(0);
}

## compare transfering bams to known.
my @moves;
if ( @bams and keys %tranf_lookup ) {
    foreach my $file (@bams) {
        if ( $tranf_lookup{$file} ) {
            $watch->info_log("$0: File $file is currently transfering");
            next;
        }
        else {
            push @moves, $file;
        }
    }
}
elsif (@bams) {
    map { push @moves, $_ } @bams;
}

## move bam files.
foreach my $mv (@moves) {
    chomp $mv;
    `mv "$xfer/$_ $process`;
    $watch->info_log("$0: $_ file moved into $process directory");
}
