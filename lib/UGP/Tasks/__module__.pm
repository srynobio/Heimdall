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
    $ENV{sqlite_file}     = '/scratch/ucgd/lustre/ugpuser/apps/kingspeak.peaks/ucgd_utils/trunk/data/UGP_DB.db';
}

## make object for record keeping.
my $heimdall = Heimdall->new( config_file => $ENV{heimdall_config} );

## path to file on ugp.chpc
my $properties  = $heimdall->config->{gnomex}->{properties};
my $gnomex_jar  = $heimdall->config->{gnomex}->{gnomex_jar};
####my $test_master_dir = $heimdall->config->{main}->{test_master_dir};
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
                Rex::Logger::info( "Analysis for $proj_name was not created.", 'warn');
                Rex::Logger::info( "Command which could not be ran: $cmd", 'warn');
                next;
            }
            else {
                Rex::Logger::info( "Analysis created for $proj_name.", 'warn');
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

desc "Checks ugp_db People table for First_Name & Last_Name match to UGP-GNomEx.";
task "check_gnomex_ugpdb_user_names",
  group => "ugp",
  sub {

    ## get ugp_db People!
    my @ugp_users = db select => {
        fields => "First_Name,Last_Name",
        from   => 'People',
    };

    my %ugp_db_lookup;
    foreach my $ugp_person (@ugp_users) {
        my $found = "$ugp_person->{First_Name}:$ugp_person->{Last_Name}";
        $ugp_db_lookup{$found}++;
    }

    ## Collect data from ugp gnomex db.
    my $gnomex_users =
      $gnomex->prepare("SELECT lastName, FirstName from AppUser");
    $gnomex_users->execute;

    my %user_to_add;
    while ( my $row = $gnomex_users->fetchrow_hashref ) {
        my $name = "$row->{FirstName}:$row->{lastName}";
        if ( !$ugp_db_lookup{$name} ) {
            $user_to_add{$name}++;
        }
    }

    foreach my $need ( keys %user_to_add ) {
        my ( $f_name, $l_name ) = split /:/, $need;
        Rex::Logger::info( "Missing user from ugp_db $need", 'warn' );
    }
};

## -------------------------------------------------- ##

1;

