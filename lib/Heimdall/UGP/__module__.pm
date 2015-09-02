package Heimdall::UGP;
use Rex -base;
use strict;
use warnings;
use feature 'say';
use XML::Simple;
use autodie;
use Heimdall;

my $watch = Heimdall->new();

## Get path from config file.
my $heimdall_ugp = $watch->config->{UCGD}->{heimdall_ugp};

#my $heimdall_ugp = '/home/srynearson/Heimdall/UGP';

## ------------------------------------------------------------ ##

task experiment_check => sub {
    my $command = 'perl experiment_check.pl';
    run "check",
      command => $command,
      cwd     => $heimdall_ugp;

    do_task "analysis_info_upload",;
};

## ------------------------------------------------------------ ##

1;

