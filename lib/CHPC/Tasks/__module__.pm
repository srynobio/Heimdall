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
    $ENV{sqlite_file}     = '/scratch/ucgd/lustre/ugpuser/apps/kingspeak.peaks/ucgd_utils/trunk/data/UGP_DB.db';
}

## using DBI due to conflict with ugp_db
my $gnomex = DBI->connect( 
    'dbi:mysql:dbname=gnomex;host=155.101.15.87',
    'srynearson', 
    'iceJihif17&'
);

## set connection to ugp_db
use Rex::Commands::DB {
    dsn => "dbi:SQLite:dbname=$ENV{sqlite_file}", "", "",
};

## make object for record keeping.
my $heimdall = Heimdall->new( config_file => $ENV{heimdall_config} );

## -------------------------------------------------- ##
## CHPC tasks
## -------------------------------------------------- ##

desc "Will check for new Projects in ugp_db and create project directories.";
no_ssh task "generate_new_projects",
  group => "chpc",
  sub {

    my $gnomex_analysis =
      $gnomex->prepare("SELECT idAnalysis,number,name from Analysis");
    $gnomex_analysis->execute;

    my %dirs;
    while ( my $row = $gnomex_analysis->fetchrow_hashref ) {
        my $project = $row->{name};
        $dirs{$project} = {
            number      => $row->{number},
            analysis_id => $row->{idAnalysis},
        };
    }

    ## get all Projects in ugp_db.
    ## and create lookup.
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
        if ( $dirs{$current} ) {
            Rex::Logger::info( "Directory $current exists", "warn" );
            next;
        }
        else {

            ## find right center first.
            my $project_space = $ugp_lookup{$current};

            my $master_path = _set_project_path($project_space);
            my $new_path    = "$master_path/$current";

            make_path($new_path);

            ## add UGP path
            my $ugp_path = "$new_path/UGP";
            make_path($ugp_path);

            ## add external data
            my $exdata_path = "$new_path/ExternalData";
            make_path($exdata_path);

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

desc "Will check ugp_db and create an individuals.txt file foreach known project.";
no_ssh task "create_individuals_files",
  group => "chpc",
  sub {
    ## ugp_db sample table.
    my @samples = db select => {
        fields => "Sample_ID,Project,Sequence_Center",
        from   => "Samples",
    };

    my %indiv;
    foreach my $part (@samples) {
        my $id     = $part->{Sample_ID};
        my $p_name = $part->{Project};
        next if ( !$id );

        push @{ $indiv{$p_name} },
          {
            id              => $part->{Sample_ID},
            sequence_center => $part->{Sequence_Center},
          };
    }

    foreach my $pep ( keys %indiv ) {

        ## find right center first.
        my $project_space = @{ $indiv{$pep} }[0]->{sequence_center};

        my $master_path = _set_project_path($project_space);
        my $project_path = "$master_path/$pep";

        next if ( !$project_path );
        my $indivFile = "$pep-individuals.txt";
        if ( -w -e $project_path ) {
            my $FH = file_write("$project_path/$indivFile");
            foreach my $out ( @{ $indiv{$pep} } ) {
                $FH->write("$out->{id}\n");
            }
            Rex::Logger::info(
                "Updating or creating individuals file for $pep project.",
                "warn" );
            $FH->close;
        }
        else {
            Rex::Logger::info(
                "Can not create individual file for $pep project.", 'warn' );
        }
    }
};

## -------------------------------------------------- ##

sub _set_project_path {
    my $project_space = shift;

    ## get data from config.
    my $process_dir = $heimdall->config->{process_directories};

    my $master_path;
    if ( $project_space =~ /nantomics/i ) {
        $master_path = $process_dir->{process}->[0];
    }
    elsif ( $project_space =~ /washu/i ) {
        $master_path = $process_dir->{process}->[1];
    }
    else {
        $master_path = $process_dir->{process}->[2];
    }
    return $master_path;
}

## -------------------------------------------------- ##
## process directory work
## -------------------------------------------------- ##

desc "Process Primary_Bams to GVCF.";
task "process_to_gvcf",
  group => 'chpc',
  sub {







};

## -------------------------------------------------- ##

1;

