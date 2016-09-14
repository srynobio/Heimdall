package CHPC::Tasks;

use Rex -base;
use feature 'say';
use File::Path qw(make_path);
use File::Copy;
use File::Find;
use Cwd 'abs_path';
use FindBin;
use lib "$FindBin::Bin/lib";
use Heimdall;

use Data::Dumper;

## set location of config and sqlite file.
BEGIN {
    $ENV{heimdall_config} = '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/heimdall.cfg';
    $ENV{sqlite_file}     = '/uufs/chpc.utah.edu/common/home/ucgdstor/common/apps/kingspeak.peaks/ucgd_utils/trunk/data/UGP_DB.db';
}

## set up db
use Rex::Commands::DB {
    dsn => "dbi:SQLite:dbname=$ENV{sqlite_file}", "", "",
};

## make object for record keeping.
my $heimdall = Heimdall->new( config_file => $ENV{heimdall_config} );

## Global calls
## will become Project directory under scratch-lustre
my $master_test_dir = $heimdall->config->{main}->{test_master_dir};
my $genomex_analysis = $heimdall->config->{repository}->{genomex_analysis};

## -------------------------------------------------- ##
## -------------------------------------------------- ##
## CHPC tasks
## -------------------------------------------------- ##

desc "Will check for new Projects in ugp_db and create project directories.";
no_ssh task "generate_new_projects",
  group => "chpc",
  sub {
    ## Make list of currently found directories
    my @current = list_files($master_test_dir);
    my %dirs;
    foreach my $in (@current) {
        chomp $in;
        $dirs{$in}++;
    }

    ## get all Project names.
    ## and create lookup.
    my @projects = db select => {
        fields => "Project",
        from   => "Projects",
    };

    my %projects;
    foreach my $name (@projects) {
        my $project_name = $name->{Project};
        $project_name =~ s/^\s+|\s+$|\/$//g;
        $projects{$project_name}++;
    }

    foreach my $current ( keys %projects ) {
        if ( $dirs{$current} ) {
            Rex::Logger::info( "Directory $current exists", "warn" );
            next;
        }
        else {
            my $new_path = "$master_test_dir/$current";
            make_path($new_path);

            my $ugp_path = "$new_path/UGP";
            make_path($ugp_path);

            ## create the needed directories
            Rex::Logger::info(
                "Building needed directories for $current project", "warn" );
            make_path(
                "$ugp_path/Data/PolishedBams",
                "$ugp_path/Data/Primary_Data",
                "$ugp_path/Reports/RunLogs",
                "$ugp_path/Reports/fastqc",
                "$ugp_path/Reports/flagstat",
                "$ugp_path/Reports/stats",
                "$ugp_path/Reports/featureCounts",
                "$ugp_path/Reports/SnpEff",
                "$ugp_path/VCF/Complete",
                "$ugp_path/VCF/GVCFs",
                "$ugp_path/VCF/WHAM",
                "$ugp_path/Analysis",
            );
        }
    }
};

## -------------------------------------------------- ##

desc "Will check ugp_db and create an individuals.txt file for each known project.";
no_ssh task "create_individuals_files",
  group => "chpc",
  sub {
    ## ugp_db sample table.
    my @samples = db select => {
        fields => "Sample_ID,Project",
        from   => "Samples",
    };

    my %indiv;
    foreach my $part (@samples) {
        my $id     = $part->{Sample_ID};
        my $p_name = $part->{Project};
        next if ( !$id );
        push @{ $indiv{$p_name} }, $id;
    }

    foreach my $peps ( keys %indiv ) {
        my $project_path = "$master_test_dir/$peps";

        if ( -e $project_path and !-e "$project_path/individuals.txt" ) {
            my $FH = file_write("$project_path/individuals.txt");
            map { say $FH->write("$_\n") } @{ $indiv{$peps} };
            Rex::Logger::info( "Individuals file created for $peps project", "warn" );
            $FH->close;
        }
    }
};

## -------------------------------------------------- ##

desc "";
no_ssh task "update_project_paths",
  group => "chpc",
  sub {

    my @projects = db select => {
        fields => "Project,PI_Last_Name",
        from   => "Projects",
    };

    my @project_names = map { $_->{Project}} @projects;
    my @pi_names = map { $_->{PI_Last_Name}} @projects;
    
    map {
        say $_->{PI_Last_Name}, "\t", $_->{Project};
      } @projects




#    while (@path_years) {
#        my $project_hash = shift @projects;
#        my $project      = $project_hash->{Project};
#        find(
#            sub {
#                _directory_info( { project_name => $project } );
#            },
#            @path_years
#        );
#    }

 };




## -------------------------------------------------- ##

sub _directory_info {

    my $dir = $File::Find::dir;
    my $file = $_;
    my $pathname = $File::Find::name;
    my $test = ${$_[0]}{project_name};



#    print Dumper $test;
#    if ($test =~ /$file/ ) {
#        print "found $test => $file";
#    }

}





## -------------------------------------------------- ##
## Nantomics process directory
## -------------------------------------------------- ##

## Get nantomics paths from config
my $n_process = $heimdall->config->{nantomics_transfer}->{process};
my $rnaseq    = $heimdall->config->{nantomics_transfer}->{rnaseq};
my $n_xfer    = $heimdall->config->{nantomics_transfer}->{xfer};

## -------------------------------------------------- ##

desc "Checks for the presence BAM files in xfer directory and move them into correct Project directory.";
no_ssh task "nantomics_xfer_transfer",
  group => 'chpc',
  sub {

    ## check xfer directory.
    my @xfer = list_files($n_xfer);
    if ( !@xfer ) {
        Rex::Logger::info( "No xfer files to transfer", "warn" );
        exit(0);
    }

    ## collect different file types.
    my @rna = grep { /RNA.*bam$/ } @xfer;
    my @dna = grep { /DNA.*bam$/ } @xfer;

    ## transfer RNA data
    map {
        my $abs_rna = abs_path($_);

        # ---> move("$abs_rna", "$rnaseq");
        say "move(\"$abs_rna\", \"$rnaseq\");";
    } @rna if @rna;

    ## xfer individuals list.
    my %xfer_ids;
    foreach my $file (@dna) {
        chomp $file;
        my ( $individual, undef ) = split /--/, $file;
        $xfer_ids{$individual} = $file;
    }

    ## ugp_db sample table.
    my @xfer_ids;
    my @samples = db select => {
        fields => "Sample_ID,Project,Sequence_Center",
        from   => "Samples",
        where  => "Sequence_Center='Nantomics'",
    };

    ## Make master Projects lookup.
    my %project;
    foreach my $collect (@samples) {
        my $project = $collect->{Project};
        my $id      = $collect->{Sample_ID};
        $project{$id} = $project;
    }

    ## Search and move.
    foreach my $dload ( keys %xfer_ids ) {
        if ( $project{$dload} ) {
            my $mv_to =
              "$master_test_dir/$project{$dload}/UGP/Data/Primary_Data";
            my $abs_xfer = abs_path( $xfer_ids{$dload} );
            say "move(\"$abs_xfer\", \"$mv_to\");";
            # ---> move("$abs_xfer", "$mv_to");
            Rex::Logger::info(
                "File: $xfer_ids{$dload} moved into project $project{$dload}.",
                "warn"
            );
        }
        else {
            Rex::Logger::info(
                "Could not find a project for file: $xfer_ids{$dload}",
                "warn" );
        }
    }
};

## -------------------------------------------------- ##

1;


__END__


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
