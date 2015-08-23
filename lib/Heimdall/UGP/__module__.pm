package Heimdall::UGP;
use Rex -base;
use strict;
use warnings;
use feature 'say';
use XML::Simple;
use autodie;

## Paths for the directory locations on UGP.
## add to cfg file.
my $ugp_path = '/home/srynearson/Heimdall/UGP';

## ------------------------------------------------------------ ##

task experiment_check => sub {
    my $command = 'perl experiment_check.pl';
    run "check",
      command => $command,
      cwd     => $ugp_path;

    do_task "analysis_info_upload",;
};

## ------------------------------------------------------------ ##

1;

