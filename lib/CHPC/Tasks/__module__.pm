package CHPC::Tasks;

use Rex -base;
use feature 'say';
use FindBin;
use lib "$FindBin::Bin/lib";
use Heimdall;

BEGIN {
    $ENV{heimdall_config} = '/home/srynearson/Heimdall/heimdall.cfg';
}

## make object for record keeping.
my $heimdall = Heimdall->new( config_file => $ENV{heimdall_config} );

## Global calls
my $fqf          = $heimdall->config->{pipeline}->{FQF};
my $g_regions    = $heimdall->config->{pipeline}->{genomic_regions};
my $e_regions    = $heimdall->config->{pipeline}->{exon_regions};
my $run_projects = $heimdall->config->{main}->{running_projects};

## -------------------------------------------------- ##

desc "TODO";
task "chpc_connect_check",
  group => "chpc",
  sub {
    my $host = run "hostname";
    if ($host) {
        say "Able to connect to server CHPC.";
    }
  };

## -------------------------------------------------- ##
## Nantomics process directory
## -------------------------------------------------- ##

## Get nantomics paths from config
my $n_process = $heimdall->config->{nantomics_transfer}->{process};
my $n_path    = $heimdall->config->{nantomics_transfer}->{path};
my $n_xfer    = $heimdall->config->{nantomics_transfer}->{xfer};
my $n_cfg     = $heimdall->config->{nantomics_transfer}->{cfg};

## -------------------------------------------------- ##

desc "TODO";
task "nantomics_data_status",
  group => 'chpc',
  sub {

    ## checking for bams or g.vcf first
    my @pd = run "ls $n_process";

    my $file_present;
    foreach my $file (@pd) {
        chomp $file;
        if ( $file =~ /(bam|g.vcf)/ ) {
            $file_present++;
        }
    }

    ## exit if file are present.
    if ($file_present) {
        Rex::Logger::info("Nantomics Process_Data directory not empty.", "error");
        exit(0);
    }

    my @xfer = run "find $n_xfer -name \"*bam\"";
    my @moved;
    foreach my $bam (@xfer) {
        chomp $bam;
        say "mv $bam $n_process";

        #run "mv $bam $o_process";
        push @moved, $bam;
    }

    map { Rex::Logger::info("File $_ moved into Processing.") } @moved;
};

## -------------------------------------------------- ##

desc "TODO";
task "process_nantomics_to_GVCF",
  group => 'chpc',
  sub {

    ## make directory & run there.
    my $date = localtime;
    $date =~ s/\s+/_/g;
    my $dir = 'FQF_Run_' . $date;

    ## make directory
    run "mkdir",
      command => "mkdir $dir",
      cwd     => $run_projects;

    ## source user bashrc
    run "source ~/.bashrc";

    my $cmd = sprintf( "%s -cfg %s -il %s -ql 100 -e cluster > foo",
        $fqf, $n_cfg, $g_regions );

    run "process",
      command => $cmd,
      cwd     => "$run_projects/$dir";
};

## -------------------------------------------------- ##
## Other process directory
## -------------------------------------------------- ##

## Get other paths from config
my $o_process = $heimdall->config->{other_transfer}->{process};
my $o_path    = $heimdall->config->{other_transfer}->{path};
my $o_xfer    = $heimdall->config->{other_transfer}->{xfer};
my $o_cfg     = $heimdall->config->{other_transfer}->{cfg};

## -------------------------------------------------- ##

desc "TODO";
task "other_data_status",
  group => 'chpc',
  sub {

    ## checking for bams or g.vcf first
    my @pd = run "ls $o_process";

    my $file_present;
    foreach my $file (@pd) {
        chomp $file;
        if ( $file =~ /(bam|g.vcf)/ ) {
            $file_present++;
        }
    }

    ## exit if file are present.
    if ($file_present) {
        Rex::Logger::info("Other process directory contains files, or directories. Exiting", "error");
        exit(0);
    }

    my @xfer = run "find $o_xfer -name \"*bam\"";
    my @moved;
    foreach my $bam (@xfer) {
        chomp $bam;
        say "mv $bam $o_process";

        #run "mv $bam $o_process";
        push @moved, $bam;
    }
    map { Rex::Logger::info("File $_ moved into Processing.") } @moved;
  };

## -------------------------------------------------- ##

desc "TODO";
task "process_other_to_GVCF",
  group => 'chpc',
  sub {

    ## make directory & run there.
    my $date = localtime;
    $date =~ s/\s+/_/g;
    my $dir = 'FQF_Run_' . $date;

    ## make directory
    run "mkdir",
      command => "mkdir $dir",
      cwd     => $run_projects;

    ## source user bashrc
    run "source ~/.bashrc";

    my $cmd = sprintf( "%s -cfg %s -il %s -ql 100 -e cluster > foo",
        $fqf, $o_cfg, $e_regions );

    my $exec = run "process",
      command => $cmd,
      cwd     => "$run_projects/$dir";

    say $exec; 
  };

## -------------------------------------------------- ##

## -------------------------------------------------- ##

1;

=pod

=head1 NAME

$::module_name - {{ SHORT DESCRIPTION }}

=head1 DESCRIPTION

{{ LONG DESCRIPTION }}

=head1 USAGE

{{ USAGE DESCRIPTION }}

 include qw/CHPC::Tasks/;

 task yourtask => sub {
    CHPC::Tasks::example();
 };

=head1 TASKS

=over 4

=item example

This is an example Task. This task just output's the uptime of the system.

=back

=cut
