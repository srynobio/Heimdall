package Heimdall::GNomEx;
use Rex -base;
use strict;
use warnings;
use feature 'say';
use XML::Simple;
use autodie;

use Data::Dumper;

## Paths for the directory locations on UGP.
## add to cfg file.
my $ugp_path = '/home/srynearson/Heimdall/UGP';

## ------------------------------------------------------------ ##

task experiments => sub {
    my $command = 'perl experiments.pl';
    my $test    = run "check",
      command => $command,
      cwd     => $ugp_path;
};

## ------------------------------------------------------------ ##

1;

