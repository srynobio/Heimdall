#!/usr/bin/env perl
# analysis_linker.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use lib '../lib';
use Heimdall;
use Getopt::Long;

my $usage = "place holder.";

my $watch = Heimdall->new();
my $dbh   = $watch->dbh;

my ($analysis_id);
GetOptions( "analysis_id|ai=s" => \$analysis_id, );

die $usage if ( !$analysis_id );

# update to remove beginning A
( my $mod_analysis = $analysis_id ) =~ s/^A//;

my $ugp_statement = "select * from UGP where AnalysisID = $mod_analysis;";
my $analysis      = $dbh->selectall_arrayref($ugp_statement);

if ( !exists $analysis->[0] ) {
    say "$0: [ERROR] could not locate AnalysisData: $analysis_id";
    exit(0);
}

my $lustre_path = "/scratch/ucgd/lustre$analysis->[0][2]";

`ln -s $lustre_path .`;

say "softlink created!";

