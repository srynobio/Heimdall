package CHPC::Tasks;

use Rex -base;
use feature 'say';
use FindBin;
use lib "$FindBin::Bin/lib";
use Heimdall;

BEGIN {
    $ENV{heimdall_config} = '/home/srynearson/Heimdall/heimdall.cfg';
}

use Rex::Commands::DB {
    dsn      => "DBI:mysql:database=gnomex;host=localhost",
    user     => "srynearson",
    password => "iceJihif17&",
};

## make object for record keeping.
my $heimdall = Heimdall->new( config_file => $ENV{heimdall_config} );

## Global calls
my $fqf             = $heimdall->config->{pipeline}->{FQF};
my $g_regions       = $heimdall->config->{pipeline}->{genomic_regions};
my $e_regions       = $heimdall->config->{pipeline}->{exon_regions};
my $run_projects    = $heimdall->config->{main}->{running_projects};
my $lustre_analysis = $heimdall->config->{repository}->{lustre_analysis_repo};
my $users_path      = $heimdall->config->{user_data_path}->{chpc};
my $report_dir      = $heimdall->config->{main}->{reports_dir};

## -------------------------------------------------- ##
## General CHPC tasks
## -------------------------------------------------- ##

desc "Will test the connection from the UGP server to Kingspeak19.";
task "chpc_connect_check",
  group => "chpc",
  sub {
    my $host = run "hostname";
    if ($host) {
        say "Able to connect to server CHPC.";
    }
};

## -------------------------------------------------- ##

desc "Check usage of Lustre for UCGD disk space offenders.";
task "check_user_usage",
  group => "chpc",
  sub {
    ## get collection of current directories
    my @user_space = run "ls $users_path";

    my @messages;
    foreach my $dir (@user_space) {
        chomp $dir;
        next if ( $dir !~ /^u\d{4,}/ );

        my $full_path = "$users_path/$dir";

        ## get username
        my $user = run "finger -s $dir";
        my ( $header, $info ) = split /\n/, $user;
        my ( $uid, $username, undef ) = split /\s{2,}/, $info;

        ## get user usage.
        my $usage = run "du -sh $full_path";
        next if ( !$username );
        my ($total, $path) =~ split/\s+/, $usage;

        ## Set up messages.        
        Rex::Logger::info("User $username\tUsage $usage");
        my $statement = sprintf(
            "User: %s\t Usage: %s\t Total: %s\n",
            $username, $usage, $total
        );
        push @messages, $statement;
    }
    $heimdall->ucgd_members_mail(\@messages);
};

## -------------------------------------------------- ##
## Nantomics process directory
## -------------------------------------------------- ##

## Get nantomics paths from config
my $n_process = $heimdall->config->{nantomics_transfer}->{process};
my $n_path    = $heimdall->config->{nantomics_transfer}->{path};
my $n_xfer    = $heimdall->config->{nantomics_transfer}->{xfer};
my $n_cfg     = $heimdall->config->{nantomics_transfer}->{cfg};
my $n_script  = $heimdall->config->{nantomics_transfer}->{scripts};

## -------------------------------------------------- ##

desc "Checks for the presence of GVCF or BAM files in nantomics Process_Data (exits if present).  Will move all xfer files to Process_Data if empty.";
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
    if ( ! @xfer ) {
        Rex::Logger::info("No xfer files to transfer", "warn");
        exit(0);
    }

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

desc "BAM files in nantomics Process_Data directory will run through FQF to GVCF.";
task "process_nantomics_to_GVCF",
  group => 'chpc',
  sub {

    ## checking for bams 
    my @pd = run "ls $n_process";

    my $file_present;
    foreach my $file (@pd) {
        chomp $file;
        ## check that gvcf files are not found.
        if ( $file =~ /g.vcf/ ) {
            Rex::Logger::info( "GVCF file[s] found, please review $n_process directory", 'error');
            exit(0);
        }
        if ( $file =~ /bam$/ ) {
            $file_present++;
        }
    }

    ## exit if file are present.
    if (! $file_present) {
        Rex::Logger::info("No BAM files found to process", 'error');
        exit(0);
    }

    ## make directory & run there.
    my $date = localtime;
    $date =~ s/\s+/_/g;
    my $dir = 'FQF_Run_' . $date;
    Rex::Logger::info("Creating report directory: $dir", 'warn');

    ## make directory
    run "mkdir",
      command => "mkdir $dir",
      cwd     => $run_projects;

    ## source bashrc
    my $source_cmd = "source ~/.bashrc";

    my $cmd = sprintf(
        "%s -cfg %s -il %s -ql 100 -e cluster > foo",
        #"%s -cfg %s -il %s -ql 100 -e cluster --run",
        $fqf, $n_cfg, $g_regions
    );
    Rex::Logger::info( "Processing data. Running command $cmd", "warn" );
      
    run "process",
      command => "$source_cmd; screen -d -m $cmd",
      cwd     => "$run_projects/$dir";
};

## -------------------------------------------------- ##

desc "TODO";
task "nantomics_transfer_processed_data", group => 'chpc',
sub {

    ## make directory
    run "indiv_find",
      command => "perl nantomics_individuals.find.pl",
      cwd     => $n_script;
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

desc "Checks for the presence of GVCF or BAM files in other Process_Data (exits if present).  Will move all xfer files to Process_Data if empty.";
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

desc "BAM files in other Process_Data directory will run through FQF to GVCF.";
task "process_other_to_GVCF",
  group => 'chpc',
  sub {

    ## checking for bams 
    my @pd = run "ls $o_process";

    my $file_present;
    foreach my $file (@pd) {
        chomp $file;
        ## check that gvcf files are not found.
        if ( $file =~ /g.vcf/ ) {
            Rex::Logger::info( "GVCF file[s] found, please review $n_process directory", 'error');
            exit(0);
        }
        if ( $file =~ /bam$/ ) {
            $file_present++;
        }
    }

    ## exit if file are present.
    if (! $file_present) {
        Rex::Logger::info("No BAM files found to process", 'warn');
        exit(0);
    }

    ## make directory & run there.
    my $date = localtime;
    $date =~ s/\s+/_/g;
    my $dir = 'FQF_Run_' . $date;
    Rex::Logger::info("Creating report directory: $dir", 'warn');

    ## make directory
    run "mkdir",
      command => "mkdir $dir",
      cwd     => $run_projects;

    ## source bashrc
    my $source_cmd = "source ~/.bashrc";

    my $cmd = sprintf(
        "%s -cfg %s -il %s -ql 100 -e cluster > foo",
        #"%s -cfg %s -il %s -ql 100 -e cluster --run",
        $fqf, $n_cfg, $g_regions
    );
    Rex::Logger::info( "Process data. Running command $cmd", "warn" );
      
    run "process",
      command => "$source_cmd; screen -d -m $cmd",
      cwd     => "$run_projects/$dir";
};

## -------------------------------------------------- ##

1;
