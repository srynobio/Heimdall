#!/usr/bin/env perl
# test_data_watch.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Heimdall;
use IO::Dir;

my $watch = Heimdall->new(
    config_file => '../../heimdall.cfg',
    log_file    => '../../watch.log'
);

## Get paths from config file.
my $path    = $watch->config->{test_transfer}->{path};
my $process = $watch->config->{test_transfer}->{process};
my $xfer    = $watch->config->{test_transfer}->{xfer};

## quick check.
unless ( -e $path and -e $process and -e $xfer ) {
    $watch->error_log(
        "$0: One or more directories not found [path, process, xfer]"
    );
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
        next unless ($xfer =~ /bam$/);
        my @lsof = split /\s/, $xfer;
        my @parts = split/\//, $lsof[-1];
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
unless (@bams) {
    $watch->info_log("$0: No complete BAM files found in $xfer");
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
chdir $xfer if (@moves);
map { 
    `mv $_ $process`;
    $watch->info_log("$0: $_ file moved into $process directory");
} @moves;

