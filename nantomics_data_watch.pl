#!/usr/bin/env perl
# nantomics_data_watch.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use Heimdall;

my $watch = Heimdall->new();

## set up paths.
my $path    = '/scratch/ucgd/lustre/nantomics-transfer';
my $process = '/scratch/ucgd/lustre/nantomics-transfer/Process_Data';
my $xfer    = '/scratch/ucgd/lustre/nantomics-transfer/xfer';

## quick check.
unless ( $path and $process and $xfer ) {
    $watch->error_log(
        "One or more directories not found [path, process, xfer]"
    );
    die;
}

## check for open fileshandles.
my @xfers = `lsof +D $nantomic_xfer`;
chomp @xfers;
$watch->info_log("No current transfering files") if ( !@xfers );

my %tranf_lookup;
if (@xfers) {
    my @lsof = split /\t/, @xfers;
    $tranf_lookup{ $lsof[8] }++;
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
    $watch->info_log("No complete BAM files found in $xfer");
    die;
}

## compare transfering bams to known.
my @moves;
if ( @bams and keys %tranf_lookup ) {
    foreach my $files (@bams) {
        if ( $tranf_lookup{$files} ) {
            next;
        }
        else {
            push @moves, $files;
        }
    }
}
elsif (@bams) {
    map { push @moves, $_ } @bams;
}

## move bam files.
#map { `mv $_ $process` } @moves;
map { say "mv $_ $process" } @moves;


__END__
## output of lsof
COMMAND   PID       USER   FD   TYPE DEVICE SIZE/OFF     NODE NAME
scp     57737 srynearson    3w   REG   8,17 1788723200 1225749 Process_Data/15-0019853_91_sorted_Dedup.bam

