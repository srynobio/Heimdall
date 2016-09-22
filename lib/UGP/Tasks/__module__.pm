package UGP::Tasks;
use File::Path qw(make_path);
use Rex -base;
use feature 'say';
use FindBin;
use lib "$FindBin::Bin/lib";
use Heimdall;
use DBI;
use XML::Simple;

use Data::Dumper;

BEGIN {
    $ENV{heimdall_config} = '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/heimdall.cfg';
    $ENV{sqlite_file}     = '/uufs/chpc.utah.edu/common/home/u0413537/ucgd_utils/data/UGP_DB.db';
}

## make object for record keeping.
my $heimdall = Heimdall->new( config_file => $ENV{heimdall_config} );

## path to file on ugp.chpc
my $properties  = $heimdall->config->{gnomex}->{properties};
my $gnomex_jar  = $heimdall->config->{gnomex}->{gnomex_jar};
my $test_master_dir = $heimdall->config->{main}->{test_master_dir};
my $repos = $heimdall->config->{gnomex}->{analysisPath};

## using DBI due to conflict with ugp_db
my $gnomex = DBI->connect(
    'dbi:mysql:dbname=gnomex;host=155.101.15.87',
    'srynearson', 
    'iceJihif17&'
);

## set up ugp_db
use Rex::Commands::DB {
    dsn => "dbi:SQLite:dbname=$ENV{sqlite_file}", "", "",
};

## -------------------------------------------------- ##

desc "Will create a UGP-GNomEx analysis for each new project and updated ugp_db.";
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
                  . "-genomeBuild human_g1k_v37 -analysisType \"UGP Analysis\" -analysisProtocal \"UGP\" ",
                $gnomex_jar, $properties, $proj_name, $lab, $proj_name );

            ## create analysis in UGP-GNomEx.
            my $createAnalysis = run $cmd;
            if ( !$createAnalysis ) {
                Rex::Logger::info( "Analysis for $proj_name was not created.",
                    'error' );
            }

            ## parse xml retun and add analysis to ugp_db.
            my $xml           = XMLin($createAnalysis);
            my $analysis_path = $xml->{filePath};
            my @pathdata      = split /\//, $analysis_path;

            $createdAnalysis{$proj_name} = $pathdata[-1];
        }
    }

    ## add newly created analysis to ugp_db
    foreach my $add ( keys %createdAnalysis ) {

        db
          update => "Projects",
          {
            set   => { Genomex_Analysis_ID => $createdAnalysis{$add}, },
            where => "Project=$add",
          };
        Rex::Logger::info(
            "Genomex_Analysis_ID: $createdAnalysis{$add} updated for project $add",
            'warn'
        );
    }
};

## -------------------------------------------------- ##

1;


__END__








desc "Reads UGP-GNomEx database for newly added Experiments. Reports if found, but no other actons.";
task "report_new_experiments", sub {

    ## rex db searches.
    my @ugp = db select => {
        fields => "*",
        from   => "UGP",
    };

    my @request = db select => {
        fields => "*",
        from   => "Request",
    };

    ## create lookup of past analysis.
    my $lookup;
    foreach my $project (@ugp) {
        next if ( $project->{ugp_project_id} eq 'NULL' );
        my $id = $project->{ugp_project_id};
        $lookup->{$id}++;
    }

    my $found_count;
    foreach my $req (@request) {
        my $request_id = $req->{idRequest} . ':' . $req->{number};

        ## rex search.
        my @appuser = db select => {
            fields1 => 'lastName',
            from    => 'AppUser',
            where   => "idAppUser=$req->{idAppUser}",
        };

        if ( !$lookup->{$request_id} ) {

            $heimdall->info_log( "$0 Making analysis for "
                  . @appuser[0]->{lastName}
                  . " lab request_id: $request_id" );

            ## rex db search.
            my @project = db select => {
                fields1 => 'name',
                field2  => 'idLab',
                from    => 'Project',
                where   => "idProject=$req->{idProject}",
            };

            ## rex db search
            my @lab = db select => {
                fields1 => 'firstname',
                fields1 => 'lastname',
                from    => 'Lab',
                where   => "idlab=@project[0]->{idLab}",
            };

            ## the lab
            my $lab = @lab[0]->{lastName} . ', ' . @lab[0]->{firstName};

            ## the project
            my $project_name = @project[0]->{name};
            $project_name =~ s/[^A-Za-z0-9]/ /g;
            $project_name =~ s/\s+/_/g;
            $project_name =~ s/_$//g;

            ## the folder name.
            my ( $cal, undef ) = split /\s+/, $req->{createDate};
            my $folder = $cal . '_' . $req->{number} . '_' . $project_name;

            say "$lab, $project_name, $folder, $req->{number}, $request_id ";
            Rex::Logger::info("Experiments reported on.");
            $found_count++;
        }
    }
    if ( !$found_count ) {
        say "No new experiments to report.";
        Rex::Logger::info("No new experiments found.");
    }
};

## -------------------------------------------------- ##

1;

__END__

desc "Reads UGP-GNomEx database for newly added Experiments. Will create new Analysis and UGP directory structure if found.";
task "complete_new_experiments", sub {

    ## list of any new experiments
    my @new_experiments;

    ## rex db searches.
    my @ugp = db select => {
        fields => "*",
        from   => "UGP",
    };

    my @request = db select => {
        fields => "*",
        from   => "Request",
    };

    ## create lookup of past analysis.
    my $lookup;
    foreach my $project (@ugp) {
        next if ( $project->{ugp_project_id} eq 'NULL' );
        my $id = $project->{ugp_project_id};
        $lookup->{$id}++;
    }

    foreach my $req (@request) {
        my $request_id = $req->{idRequest} . ':' . $req->{number};

        ## rex search.
        my @appuser = db select => {
            fields1 => 'lastName',
            from    => 'AppUser',
            where   => "idAppUser=$req->{idAppUser}",
        };

        if ( !$lookup->{$request_id} ) {

            $heimdall->info_log( "$0 Making analysis for "
                  . @appuser[0]->{lastName}
                  . " lab request_id: $request_id" );

            ## rex db search.
            my @project = db select => {
                fields1 => 'name',
                field2  => 'idLab',
                from    => 'Project',
                where   => "idProject=$req->{idProject}",
            };

            ## rex db search
            my @lab = db select => {
                fields1 => 'firstname',
                fields1 => 'lastname',
                from    => 'Lab',
                where   => "idlab=@project[0]->{idLab}",
            };

            ## the lab
            my $lab = @lab[0]->{lastName} . ', ' . @lab[0]->{firstName};

            ## the project
            my $project_name = @project[0]->{name};
            $project_name =~ s/[^A-Za-z0-9]/ /g;
            $project_name =~ s/\s+/_/g;
            $project_name =~ s/_$//g;

            ## the folder name.
            my ( $cal, undef ) = split /\s+/, $req->{createDate};
            my $folder = $cal . '_' . $req->{number} . '_' . $project_name;

            push @new_experiments,
              [ $lab, $project_name, $folder, $req->{number}, $request_id ];
        }
    }

    if (@new_experiments) {
        _analysis_build_update_db(@new_experiments);
    }
    else {
        Rex::Logger::info("$0 No new experiments found.");
        exit(0);
    }
};

## -------------------------------------------------- ##

desc "If sample annotations are filled in, an individuals.txt file per-project will be created and added.";
task "create_individuals_files",
  group => 'ugp',
  sub {

    ## rex db call
    my @ugp = db select => {
        fields => "*",
        from   => 'UGP',
    };

    my %requests;
    foreach my $return (@ugp) {
        next if ( $return->{AnalysisDataPath} eq 'NULL' );
        my ( $idRequest, undef ) = split /:/, $return->{ugp_project_id};
        next if ( ! $idRequest );
        $requests{$idRequest} = $return->{AnalysisDataPath};
    }

    foreach my $id ( keys %requests ) {
        my @sample = db select => {
            fields => "idRequest, name",
            from   => 'Sample',
            where  => "idRequest=$id"
        };

        ## make the individuals.txt path.
        $requests{$id} =~ s|/UGP$||;
        my $indiv_file = $requests{$id} . '/individuals.txt';
        Rex::Logger::info("Creating individuals.txt for project $indiv_file.");

        open( my $OUT, '>', $indiv_file );

        foreach my $individual (@sample) {
            say $OUT $individual->{name};
        }
        close $OUT;
    }
};

## -------------------------------------------------- ##

desc "If user creates their own analysis, a new UGP directory structure will be created for it.";
task "find_user_created_analysis",
  group => "ugp",
  sub {
    my @ugp = db select => {
        fields => "AnalysisID",
        from   => "UGP",
    };

    my %ugp_lookup;
    foreach my $known (@ugp) {
        chomp $known;
        next if ( $known eq 'NULL' );
        my $analysis = "A" . $known->{AnalysisID};
        $ugp_lookup{$analysis}++;
    }

    ## get list of analysis created.
    my @analysis = db select => {
        fields => "*",
        from   => "Analysis"
    };

    my @analysis_update;
    foreach my $study (@analysis) {
        if ( !$ugp_lookup{ $study->{number} } ) {

            ## will return 1..* elements
            my @analysisFile = db select => {
                fields => "baseFilePath, createDate",
                from   => "AnalysisFile",
                where  => "idAnalysis=$study->{idAnalysis}",
            };

            ## unless undef
            if ( !@analysisFile ) {
                Rex::Logger::info(
                    "Analysis $study->{number} created with no known data files",
                    "warn"
                );
                next;
            }

            ## some createDate are not created in gnomex!?
            if ( !@analysisFile[0]->{createDate} ) {
                ( my $createDate, undef ) = split /\s+/, @analysis[0]->{createDate};
                @analysisFile[0]->{createDate} = $createDate;
            }

            ## name clean up (same for experiment create).
            my $filename =
              @analysisFile[0]->{createDate} . "_" . $study->{name};
            $filename =~ s/[^A-Za-z0-9]/ /g;
            $filename =~ s/\s+/_/g;
            $filename =~ s/_$//g;

            @analysisFile[0]->{baseFilePath} =~ s|/UGP||g;
            my $ugp_path =
              @analysisFile[0]->{baseFilePath} . "/" . $filename . "/" . "UGP";

            my @dirs = (
                "$ugp_path",                   "$ugp_path/Data",
                "$ugp_path/Data/PolishedBams", "$ugp_path/Data/Primary_Data",
                "$ugp_path/Analysis",          "$ugp_path/Reports/flagstat",
                "$ugp_path/Reports/stats",     "$ugp_path/Reports/fastqc",
                "$ugp_path/Reports/BAMQC",     "$ugp_path/Reports/VCFQC",
                "$ugp_path/VCF/GVCFs",         "$ugp_path/VCF/Complete",
                "$ugp_path/VCF/WHAM",
            );

            map { make_path($_) } @dirs;
            Rex::Logger::info(
                "$0 Making UGP directory structure for analysis A$study->{idAnalysis}"
            );
            push @analysis_update, [ $ugp_path, $study->{idAnalysis} ];
        }
    }

    ## Update UGP db via rex.
    foreach my $update (@analysis_update) {
        db
          insert => "UGP",
          {
            AnalysisDataPath => $update->[0],
            AnalysisID       => $update->[1],
          };
    }
};

## -------------------------------------------------- ##
## Task methods.
## -------------------------------------------------- ##

sub _analysis_build_update_db {
    my @lab_meta = @_;

    my @ugp_table_update_info;
    foreach my $lab (@lab_meta) {
        my $cmd = sprintf(
            "java -classpath %s hci.gnomex.httpclient.CreateAnalysisMain "
              . "-properties %s -server ugp.chpc.utah.edu "
              . "-name \"%s\" -lab \"%s\" -folderName \"%s\" -organism \"Human\" "
              . "-genomeBuild human_g1k_v37 -analysisType \"UGP Analysis\" -analysisProtocal \"UGP\" "
              . "-experiment %s",
            $gnomex_jar, $properties, $lab->[1],
            $lab->[0],   $lab->[2],   $lab->[3]
        );

        ##run and parse result.
        my $result = `$cmd`;

        ## check system return for errors.
        if ($?) {
            $heimdall->ERROR(
                "CreateAnalysisMain for $lab->[2] could not be created. Message: $?"
            );
        }

        ## parse the java return
        my $ref                   = XMLin($result);
        my $analysis_project_path = $ref->{filePath};
        my $new_analysis_id       = $ref->{idAnalysis};

        my $ugp_path = "$analysis_project_path/$lab->[2]/UGP";
        $ugp_path =~ s|^/UGP||;

        my @dirs = (
            "$ugp_path",                   "$ugp_path/Data",
            "$ugp_path/Data/PolishedBams", "$ugp_path/Data/Primary_Data",
            "$ugp_path/Analysis",          "$ugp_path/Reports/flagstat",
            "$ugp_path/Reports/stats",     "$ugp_path/Reports/fastqc",
            "$ugp_path/Reports/BAMQC",     "$ugp_path/Reports/VCFQC",
            "$ugp_path/VCF/GVCFs",         "$ugp_path/VCF/Complete",
            "$ugp_path/VCF/WHAM",
        );

        map { make_path($_) } @dirs;
        Rex::Logger::info("$0 Making UGP directory structure for $lab->[2]");

        push @ugp_table_update_info,
          [ $lab->[4], $ugp_path, $lab->[3], $new_analysis_id ];
    }

    ## Update UGP db via rex.
    foreach my $update (@ugp_table_update_info) {
        db
          insert => "UGP",
          {
            ugp_project_id   => $update->[0],
            AnalysisDataPath => $update->[1],
            AnalysisID       => $update->[2],
            project          => $update->[3],
          };
    }
}

## -------------------------------------------------- ##

1;

