package UGP::Tasks;
use XML::Simple;
use File::Path qw(make_path);
use Rex -base;
use feature 'say';
use FindBin;
use lib "$FindBin::Bin/lib";
use Heimdall;

use Rex::Commands::DB {
    dsn      => "DBI:mysql:database=gnomex;host=localhost",
    user     => "srynearson",
    password => "iceJihif17&",
};

BEGIN {
    $ENV{heimdall_config} = '/home/srynearson/Test/heimdall.cfg';
}

## make object for record keeping.
my $heimdall = Heimdall->new( config_file => $ENV{heimdall_config} );

my $properties = $heimdall->config->{gnomex}->{properties};
my $gnomex_jar = $heimdall->config->{gnomex}->{gnomex_jar};
my $task_dir   = $heimdall->config->{main}->{task_dir};

## -------------------------------------------------- ##

desc "TODO";
task "new_experiments", sub {

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

            $heimdall->info_log( 
                "$0 Making analysis for "
                  . @appuser[0]->{lastName}
                  . " lab request_id: $request_id"
              );

            ## rex db search.
            my @project = db select => {
                fields1 => 'name',
                field2  => 'idLab',
                from    => 'Project',
                where   => "idProject=$req->{idProject}",
            };

            ## rex db search
            my @lab = db select => {
                fields1 => 'firstName',
                fields1 => 'lastName',
                from    => 'Lab',
                where   => "idLab=@project[0]->{idLab}",
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

            push @new_experiments, [$lab, $project_name, $folder, $req->{number}, $request_id];
        }
    }

    if (@new_experiments) {
        _analysis_build_update_db(@new_experiments);
    }
    else {
        $heimdall->info_log("$0 No new experiments found.");
        exit(0);
    }
};


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
            $heimdall->error_log(
                "CreateAnalysisMain for $lab->[2] could not be created. Message: $?"
            );
        }

        ## parse the java return
        my $ref                   = XMLin($result);
        my $analysis_project_path = $ref->{filePath};
        my $new_analysis_id       = $ref->{idAnalysis};

        my $ugp_path = "$analysis_project_path/$lab->[2]/UGP";

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
        $heimdall->info_log("$0 Making UGP directory structure for $lab->[2]");

        push @ugp_table_update_info,
          [ $lab->[4], $ugp_path, $lab->[3], $new_analysis_id ];
    }

    ## Update UGP db via rex.
    foreach my $update (@ugp_table_update_info) {
        db insert => "UGP",
          {
            ugp_project_id   => $update->[0],
            AnalysisDataPath => $update->[1],
            AnalysisID       => $update->[2],
            project          => $update->[3],
          };
    }
}

## -------------------------------------------------- ##

desc "TODO";
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

        say $indiv_file;
        open( my $OUT, '>', $indiv_file );

        foreach my $individual (@sample) {
            say $OUT $individual->{name};
        }
        close $OUT;
    }
};

## -------------------------------------------------- ##

desc "TODO";
task "ugp_connect_check", group => "ugp", sub {
    my $host = run "hostname";
    if ( $host ) {
        say "Able to connect to server UGP.";
    }
};

## -------------------------------------------------- ##

1;


=pod

=head1 NAME

$::module_name - {{ SHORT DESCRIPTION }}

=head1 DESCRIPTION

{{ LONG DESCRIPTION }}

=head1 USAGE

{{ USAGE DESCRIPTION }}

 include qw/UGP::Tasks/;

 task yourtask => sub {
    UGP::Tasks::example();
 };

=head1 TASKS

=over 4

=item example

This is an example Task. This task just output's the uptime of the system.

=back

=cut
