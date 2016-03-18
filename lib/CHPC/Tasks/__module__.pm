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

desc "Check usage of /scratch/ucgd/lustre for UCGD disk space offenders.";
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
            Rex::Logger::info( "GVCF file[s] found, process step error", "error" );
            exit(0);
        }
        if ( $file =~ /bam$/ ) {
            $file_present++;
        }
    }

    ## exit if file are present.
    if (! $file_present) {
        Rex::Logger::info("No data to process", "warn");
        exit(0);
    }

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

    my $cmd = sprintf(
        #"nohup %s -cfg %s -il %s -ql 100 -e cluster --run",
        "nohup %s -cfg %s -il %s -ql 100 -e cluster > foo",
        $fqf, $n_cfg, $g_regions
    );
    Rex::Logger::info( "Process data. Running command $cmd", "warn" );

    run "process",
      command => $cmd,
      cwd     => "$run_projects/$dir";
};

## -------------------------------------------------- ##

desc "TODO";
task "nantomics_transfer_processed_data", group => 'chpc',
sub {

    my $n_process = $heimdall->config->{nantomics_transfer}->{process};
my $n_path    = $heimdall->config->{nantomics_transfer}->{path};
my $n_xfer    = $heimdall->config->{nantomics_transfer}->{xfer};
my $n_cfg     = $heimdall->config->{nantomics_transfer}->{cfg};

my $analysis_dir = $heimdall->config->{repository}->{lustre_analysis_repo};

# from config
my $analysis = '/scratch/ucgd/lustre/ugpuser/Repository/AnalysisData';
my $process  = '/scratch/ucgd/lustre/nantomics-transfer/Process_Data';

## Global collection
my $project_ids;
my $processed;

find (\&id_find, $analysis_dir);
find (\&get_processed, $process);

## process data check
if ( ! keys %{$processed} ) {
    say "No data found to transfer";
        exit(0);
        }

        foreach my $proj (keys %{$project_ids}) {
            foreach my $indiv (@{$project_ids->{$proj}->{ids}}) {

                    my @found = grep { $_ =~ /^$indiv.*/ } keys %{$processed};
                            next if ( ! @found );

                                    move_to_project( \@found, $project_ids->{$proj}->{path});
                                            delete $processed->{$found[0]};
                                                }
                                                }

                                                map { say "file with no home: $_" } keys %$processed;



























    
    my @analysisDataPath = db select => {
        fields => 'AnalysisDataPath',
        from   => 'UGP',
    };

    map { say $_->{AnalysisDataPath} } @analysisDataPath;

=cut

        my $indi_find = "find $lustre_analysis -name \"individuals.txt\"";
        my @indi_files = run $indi_find;
   

        foreach my $file (@indi_files) {
            chomp $file;

            say $file;

            my $FH;
            eval { 
                $FH = file_read($file);
            };
            Rex::Logger::info("Error occured reading file $file.", "warn") if ($@);

            for my $id ($FH->read_all) {
                say $id;
            }
            #my $content = $FH->read_all;
            #say "start: $content";
            $FH->close;
        }




    my @year_dir =  list_files($lustre_analysis);    

    my @years;
    foreach my $dir ( @year_dir ) {
        my @repo_contents = list_files("$lustre_analysis/$dir");

        foreach my $analysis_dir (@repo_contents) {
            my 
            say $analysis_dir;
        }

        #use Data::Dumper;
        #print Dumper 'shawn', $dir, @test;
    }

        next if ( $dir !~ /20*/ );
        push @years, $dir;
    }

    my @path_years = map { "$lustre_analysis/$_" } @years;

    foreach my $i ( @path_years ) {
        my @test = list_files($i);
    
        use Data::Dumper;
        print Dumper @test;
    }
=cut



#my $lustre_analysis = $heimdall->config->{repository}->{lustre_analysis_repo};
#my $n_process = $heimdall->config->{nantomics_transfer}->{process};






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
