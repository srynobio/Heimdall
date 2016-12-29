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

## set location of config and sqlite file.
## update on project move.
BEGIN {
    $ENV{heimdall_config} =
        '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/heimdall.cfg';
    $ENV{sqlite_file} =
        '/scratch/ucgd/lustre/ugpuser/apps/kingspeak.peaks/ucgd_utils/trunk/data/UGP_DB.db';
}

## set connection to ugp_db
use Rex::Commands::DB {
    dsn => "dbi:SQLite:dbname=$ENV{sqlite_file}",
    "", "",
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

    ## get directory doc file
    my $dir_docs = $heimdall->config->{docs}->{directory_doc};

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
            Rex::Logger::info( "Directory $new_path exists, skipping.",
                "warn" );
            next;
        }
        make_path( $new_path, { error => \my $err } );

        ## only need to check high level.
        if (@$err) {
            Rex::Logger::info(
                "Error occured making directory $new_path, skipping", "warn" );
            next;
        }

        ## add UGP path
        my $ugp_path = "$new_path/UGP";
        make_path($ugp_path);

        ## copy directory overview to each new project
        copy( $dir_docs, $new_path );

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

desc
  "Will check ugp_db and create an individuals.txt file foreach known project.";

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

sub _set_project_path {
    my $project_space = shift;

    ## get data from config.
    my $process_dir = $heimdall->config->{process_directories};

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

1;

