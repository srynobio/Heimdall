use Rex -feature => ['1.3'];
use feature 'say';
use File::Copy;
use File::Path qw(make_path);
use Heimdall;

logging to_file => "Heimdall.run.log";
set connection  => "SSH";

## set location of config and sqlite file.
## update on project move.
BEGIN {
    $ENV{heimdall_config} =
        '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/heimdall.cfg';
    $ENV{sqlite_file} =
        '/scratch/ucgd/lustre/ugpuser/apps/kingspeak.peaks/ucgd_utils/trunk/data/UGP_DB.db';
}

## make object for record keeping.
my $heimdall = Heimdall->new( config_file => $ENV{heimdall_config} );

## set data from config file.
my $configs     = $heimdall->config->{config_files}->{cfg};
my $thousand    = $heimdall->config->{backgrounds}->{thousand};
my $longevity   = $heimdall->config->{backgrounds}->{longevity};
my $properties  = $heimdall->config->{gnomex}->{properties};
my $gnomex_jar  = $heimdall->config->{gnomex}->{gnomex_jar};
my $process_dir = $heimdall->config->{process_directories};
my $dir_docs    = $heimdall->config->{docs};

## make sure ucgd_modules is loaded.
system("module load ucgd_modules");

## -------------------------------------------------- ##
## Create connections to DBs
## -------------------------------------------------- ##

## using DBI due to conflict with ugp_db
my $gnomex = DBI->connect( 
    'dbi:mysql:dbname=gnomex;host=155.101.15.87',
    'srynearson', 'iceJihif17&' );

## set connection to ugp_db
use Rex::Commands::DB {
    dsn => "dbi:SQLite:dbname=$ENV{sqlite_file}",
    "", "",
};

## -------------------------------------------------- ##
## Tasks 
## -------------------------------------------------- ##

desc "Update and populate all projects with current documents in docs/";
task "update_docs", sub {

    ## Get project info from ugp_db
    my @ugp_db_projects = db select => {
        fields => "Project",
        from   => "Projects",
    };

    ## create quick project lookup;
    ## so only know projects are written to.
    my %project_lk;
    foreach my $return (@ugp_db_projects) {
        $project_lk{ $return->{Project} }++;
    }

    foreach my $dir ( @{ $process_dir->{process} } ) {
        my @proj_dirs     = list_files($dir);
        my $dir_documents = $dir_docs->{directory_doc};

        foreach my $project (@proj_dirs) {
            next if ( !$project_lk{$project} );
            foreach my $docs ( @{$dir_documents} ) {
                Rex::Logger::info("Updating project: $project with /doc files");
                copy( "$docs", "$dir/$project" );
            }
        }
    }
};

## -------------------------------------------------- ##

desc
  "Will create a UGP-GNomEx analysis for each new project and updated ugp_db.";
task "create_gnomex_analysis",
  group => "ugp",
  sub {

    ## Get project info from ugp_db
    my @ugp_db_projects = db select => {
        fields => "Project,PI_First_Name,PI_Last_Name",
        from   => "Projects",
    };

    ## make lookup table.
    my %project_lookup;
    foreach my $proj (@ugp_db_projects) {
        $project_lookup{ $proj->{Project} }++;
    }

    ## Collect data from ugp gnomex db.
    my $gnomex_analysis = $gnomex->prepare("SELECT name from Analysis");
    $gnomex_analysis->execute;

    ## delete what is already created.
    while ( my $row = $gnomex_analysis->fetchrow_hashref ) {
        my $done_project = $row->{name};
        $done_project =~ s|\s+$||g;
        $done_project =~ s|^\s+||g;
        if ( $project_lookup{$done_project} ) {
            delete $project_lookup{$done_project};
        }
    }

    my %createdAnalysis;
    foreach my $create (@ugp_db_projects) {
        my $proj_name = $create->{Project};

        if ( $project_lookup{$proj_name} ) {
            my $firstName = $create->{PI_First_Name};
            my $lastName  = $create->{PI_Last_Name};
            my $lab       = "$lastName, $firstName";
            my $cmd       = sprintf(
                "java -classpath %s hci.gnomex.httpclient.CreateAnalysisMain "
                  . "-properties %s -server ugp.chpc.utah.edu "
                  . "-name \"%s\" -lab \"%s\" -folderName \"%s\" -organism \"Human\" "
                  . "-genomeBuild human_g1k_v37 -analysisType \"UGP Analysis\" -analysisProtocal \"UGP\"",
                $gnomex_jar, $properties, $proj_name, $lab, $proj_name, );

            ## run the command on ugp.
            say $cmd;

#            my $result = run "$cmd";
#
#            if ( !$result ) {
#                Rex::Logger::info( "Command $cmd could not be ran remotely.",
#                    'warn' );
#            }
#
#            ## parse xml retun and add analysis to ugp_db.
#            my $xml           = XMLin($result);
#            my $analysis_path = $xml->{filePath};
#            my @pathdata      = split /\//, $analysis_path;
#
#            $createdAnalysis{$proj_name} = $pathdata[-1];
        }
    }
  };

## -------------------------------------------------- ##

desc "Set up FQF per project.
Required option:
    --project=<UGP project name>
    --background=<longevity or thousand>
";
task "create_FQF_project", sub {
    my $command_line = shift;

    ## get project from command line.
    my $project = $command_line->{project};
    if ( !$project ) {
        Rex::Logger::info( "Option not given (--project=[project])", "error" );
    }

    ## Get project info from ugp_db
    my @ugp_db_samples = db select => {
        fields => "Project,Sequence_Center,Seq_Design",
        from   => "Samples",
    };

    my $seq_design;
    my $seq_center;
    foreach my $sample (@ugp_db_samples) {
        if ( $sample->{Project} eq $project ) {
            $seq_design = $sample->{Seq_Design};
            $seq_center = $sample->{Sequence_Center};
            last;
        }
    }

    ## Quick check
    if ( !$seq_design and $seq_center ) {
        Rex::Logger::info(
            "Seq_design and Sequence_Center not found in ugp_db for your project",
            "error"
        );
    }

    ## set up correct transfer space and open
    my $process_dir;
    if ( $seq_center eq 'Nantomics' ) {
        $process_dir = $heimdall->config->{nantomics_transfer}->{process};
    }
    elsif ( $seq_center eq 'WashU' ) {
        $process_dir = $heimdall->config->{washu_transfer}->{process};
    }
    elsif ( $seq_center eq 'other' ) {
        $process_dir = $heimdall->config->{other_transfer}->{process};
    }
    opendir( my $PROC, $process_dir )
      or Rex::Logger::info( "Can't open directory $process_dir, exiting.",
        'error' );

    ## set up the background location.
    ## once ugp_db is updated to include backround this section will change.
    my $background;
    my $background_name;
    my $command_background = $command_line->{background};
    if ( $command_line->{background} =~ /longevity/i ) {
        $background      = $longevity;
        $background_name = 'Longevity';
    }
    elsif ( $command_line->{background} =~ /thousand/i ) {
        $background      = $thousand;
        $background_name = '1000Genomes';
    }

    ## set region file to use.
    my $region;
    if ( $seq_design eq 'WGS' ) {
        $region = $heimdall->config->{region_files}->{WGS};
    }
    elsif ( $seq_design eq 'WES' ) {
        $region = $heimdall->config->{region_files}->{WES};
    }

    ## data path.
    my $primary_data = "$process_dir/$project/UGP/Data/Primary_Data/";

    ## make tmp processing directory and ln to tmp.
    my $process_project = "$process_dir/$project/UGP";
    if ( !-e $process_project ) {
        Rex::Logger::info( "[ERROR] $process_project does not exist!",
            "error" );
    }

    ## check if file exist.
    my @bam_files = glob "$primary_data/*bam";

    if ( !@bam_files ) {
        Rex::Logger::info( "No BAM file found in $primary_data directory",
            "error" );
    }

    ## fqf_id
    my $epoch = time;
    my $fqf_id =
      'FQF-1.3.3_' . $project . '_' . $background_name . '_' . $epoch;

    my @updated_cfgs;
    opendir( my $CFG, $configs );
    foreach my $c_file ( readdir $CFG ) {
        next if ( $c_file !~ /cfg$/ );
        cp( "$configs/$c_file", $process_project );

        my $data_cmd = sprintf(
            "perl -p -i -e 's|^data:|data:$process_project|' $process_project/$c_file"
        );
        my $fqf_cmd = sprintf(
            "perl -p -i -e 's|^fqf_id:|fqf_id:$fqf_id|' $process_project/$c_file"
        );
        my $back_cmd = sprintf(
            "perl -p -i -e 's|^backgrounds:|backgrounds:$background|' $process_project/$c_file"
        );
        my $region_cmd = sprintf(
            "perl -p -i -e 's|^region:|region:$region|' $process_project/$c_file"
        );

        # run commands.
        `$data_cmd`;
        `$fqf_cmd`;
        `$back_cmd`;
        `$region_cmd`;

        push @updated_cfgs, "$process_project/$c_file";
    }

    my $shell = <<"EOM";
#!/bin/bash

module load ucgd_modules

cd $process_project

## update trello
TrelloTalk -project $project -action pipeline_start

## toGVCF
FQF -cfg $updated_cfgs[0] --run

## checkpoint
read -p "GVCFs created, press [Enter] to continue..."

## update trello
TrelloTalk -project $project -action bams_complete
TrelloTalk -project $project -action gvcf_complete

## Genotype
FQF -cfg $updated_cfgs[2] --run

## checkpoint
read -p "Genotyping done, press [Enter] to continue..."

## update trello
TrelloTalk -project $project -action vcf_complete

## qc
FQF -cfg $updated_cfgs[1] --run
FQF -cfg $updated_cfgs[3] --run

## checkpoint
read -p "QC and WHAM steps done, press [Enter] to continue...

## update trello
TrelloTalk -project $project -action qc_complete
TrelloTalk -project $project -action wham_complete
TrelloTalk -project $project -action pipeline_finished

wait

echo "$project done processing"

EOM

    my $bash_file = "$process_project/$project.sh";
    open( my $OUT, '>', $bash_file );
    chmod 755, $bash_file;

    say $OUT $shell;
    close $OUT;
};

## -------------------------------------------------- ##

desc "Will check for new Projects in ugp_db and create project directories.";
task "create_new_projects", sub {

    ## get all Projects in ugp_db.
    ## and create lookup table.
    my @projects = db select => {
        fields => "Project,Sequence_Center",
        from   => "Projects",
    };

    my %ugp_lookup;
    foreach my $ugp (@projects) {
        my $project_name = $ugp->{Project};
        $project_name =~ s/^\s+|\s+$|\/$//g;
        $ugp_lookup{$project_name} =
          { sequence_center => $ugp->{Sequence_Center}, };
    }

    foreach my $current ( keys %ugp_lookup ) {

        my $project_space = $ugp_lookup{$current};

        ## find right center first.
        if ( $project_space->{sequence_center} !~
            /(WashU|Washington|Nantomics)/i )
        {
            $project_space->{sequence_center} = 'other';
        }

        my $master_path = _set_project_path($project_space);
        my $new_path    = "$master_path/$current";

        ## skip if exists
        if ( -e $new_path ) {
            Rex::Logger::info( "[SKIPPING] Directory $new_path exists.",
                "warn" );
            next;
        }
        make_path( $new_path, { error => \my $err } );

        ## only need to check high level.
        if (@$err) {
            Rex::Logger::info(
                "[NON FATAL ERROR] Error occured making directory $new_path, skipping",
                "warn"
            );
            next;
        }

        ## add UGP path
        my $ugp_path = "$new_path/UGP";
        make_path($ugp_path);

        ## add external data
        my $exdata_path = "$new_path/ExternalData";
        make_path($exdata_path);

        ## create the needed directories
        Rex::Logger::info( "Building needed directories for $current project",
            "warn" );
        make_path( "$ugp_path/Data/Primary_Data", "$ugp_path/Analysis", );
    }
};

## -------------------------------------------------- ##

desc "Will check ugp_db and create an individuals.txt file for each known project.";
task "create_individuals_files", sub {
    ## ugp_db sample table.
    my @samples = db select => {
        fields => "Sample_ID,Project,Sequence_Center",
        from   => "Samples",
    };

    my %indiv;
    foreach my $part (@samples) {
        my $id     = $part->{Sample_ID};
        my $p_name = $part->{Project};
        next if ( !$p_name );
        next if ( !$id );

        push @{ $indiv{$p_name} },
          {
            id              => $part->{Sample_ID},
            sequence_center => $part->{Sequence_Center},
          };
    }

    foreach my $pep ( keys %indiv ) {
        ## find right center first.
        my $project_space = $indiv{$pep}[0];

        if ( $project_space->{sequence_center} !~
            /(WashU|Washington|Nantomics)/i )
        {
            $project_space->{sequence_center} = 'other';
        }

        my $master_path  = _set_project_path($project_space);
        my $project_path = "$master_path/$pep";

        next if ( !$project_path );
        my $indivFile = "$pep-individuals.txt";
        if ( -w -e $project_path ) {
            my $FH = file_write("$project_path/$indivFile");
            foreach my $out ( @{ $indiv{$pep} } ) {
                $FH->write("$out->{id}\n");
            }
            Rex::Logger::info(
                "Updating or creating individuals file for $pep project in $project_path.",
                "warn"
            );
            $FH->close;
        }
        else {
            Rex::Logger::info(
                "Can not create individual file for $pep project in $project_path",
                'warn'
            );
        }
    }
};

## -------------------------------------------------- ##
## Helper methods 
## -------------------------------------------------- ##

sub _set_project_path {
    my $project_space = shift;

    ## uses process_dir from above setting config files.
    my $master_path;
    if ( $project_space->{sequence_center} =~ /Nantomics/i ) {
        $master_path = $process_dir->{process}->[0];
    }
    elsif ( $project_space->{sequence_center} =~ /(WashU|Washington)/i ) {
        $master_path = $process_dir->{process}->[1];
    }
    elsif ( $project_space->{sequence_center} =~ /other/i ) {
        $master_path = $process_dir->{process}->[2];
    }
    return $master_path;
}

## -------------------------------------------------- ##

sub timestamp {
    my $self = shift;
    my $time = localtime;
    return $time;
}

## -------------------------------------------------- ##

1;

