#!/usr/bin/env perl
# experiments.pl
use strict;
use warnings;
use DBI;
use XML::Simple;
use File::Path qw(make_path);
use feature 'say';
use lib '../lib';
use Heimdall;

# Get base utilities
my $watch = Heimdall->new();
my $dbh   = $watch->dbh;

check_request_db();
analysis_id_name_report();

## ------------------------------------------------------------ ##

sub check_request_db {

    #sub new_experiment_check {
    my $sth = $dbh->prepare(
        "select idRequest, name, idRequest, number, createDate, idProject, idLab, idAppUser from Request;"
    );
    $sth->execute();

    my $experiment_hash;
    while ( my $request = $sth->fetchrow_hashref() ) {

        ## get ugp_project for lookup and create date from Request.
        my $ugp_project = $request->{idRequest} . ':' . $request->{number};
        my ( $cal, undef ) = split /\s+/, $request->{createDate};

        ### from Lab table get name for analysis creation.
        my $lab_statement =
          "select firstName, lastName from Lab where idLab = "
          . $request->{idLab} . ";";
        my $name_ref = $dbh->selectall_arrayref($lab_statement);

        # build the lab name
        my $firstname = $name_ref->[0][0];
        my $lastname  = $name_ref->[0][1];
        my $lab       = "$lastname, $firstname";

        ### collect project and folder information
        my $project_statement =
          "select name from Project where idProject = "
          . $request->{idProject} . ";";
        my $proj_ref = $dbh->selectall_arrayref($project_statement);

        my $project_name = $proj_ref->[0][0];
        $project_name =~ s/[^A-Za-z0-9]/ /g;
        $project_name =~ s/\s+/_/g;

        # make folder name.
        my $folder = $cal . '_' . $request->{number} . '_' . $project_name;

        # make hash.
        $experiment_hash->{$ugp_project} = {
            project      => $request->{number},
            project_name => $project_name,
            folder       => $folder,
            lab          => $lab
        };
    }

    # check if new project exist.
    # Then create analysis for new projects.
    my $new_projects = _new_project_check($experiment_hash);
    _create_gnomex_analysis($new_projects);

    $sth->finish();
    return $experiment_hash;
}

## ------------------------------------------------------------ ##

sub _new_project_check {
    my $experiment_hash = shift;

    # collect known id from ugp table.
    my $ugp_project_statement = "select check_project_id from UGP;";
    my $project_ref = $dbh->selectall_arrayref($ugp_project_statement);

    foreach my $exp ( keys %{$experiment_hash} ) {
        foreach my $known ( @{$project_ref} ) {
            if ( $exp eq $known->[0] ) {
                delete $experiment_hash->{$exp};
            }
        }
    }

    # this unless will be the "no new data" exit point.
    unless ( keys %{$experiment_hash} ) {
        $watch->info_log("No new experiments");
    }
    return $experiment_hash;
}

## ------------------------------------------------------------ ##

sub _create_gnomex_analysis {
    my $new_projects = shift;

    # This will system call to the GNomEx utility CreateAnalysisMain
    # Which will add the Analysis to GNomEx.

    my @errors;
    my @project_info;
    foreach my $new ( keys %{$new_projects} ) {

        my $lab          = $new_projects->{$new}->{lab};
        my $project      = $new_projects->{$new}->{project};
        my $project_name = $new_projects->{$new}->{project_name};
        my $folder       = $new_projects->{$new}->{folder};

        my $cmd = sprintf(
            "java -classpath gnomex_client.jar hci.gnomex.httpclient.CreateAnalysisMain "
              . "-properties properties -server ugp.chpc.utah.edu "
              . "-name \"%s\" -lab \"%s\" -folderName \"%s\" -organism \"Human\" "
              . "-genomeBuild human_g1k_v37 -analysisType \"UGP Analysis\" -analysisProtocal \"UGP\" "
              . "-experiment %s\n",
            $project_name, $lab, $folder, $project );

        # run and parse result.
        my $result = `$cmd`;

        if ( ! length $result > 1 ) {
            push @errors, "project $project could not be created";
            next;
        }

        my $ref        = XMLin($result);
        my $filepath   = $ref->{filePath};
        my $idAnalysis = $ref->{idAnalysis};

        my $new_dir = "$filepath/$folder";
        if ( ! -d $new_dir ) {
            make_path(
                "$new_dir",
                "$new_dir/Data",
                "$new_dir/Data/PolishedBams",
                "$new_dir/Data/Primary_Data",
                "$new_dir/QC",
                "$new_dir/Analysis",
                "$new_dir/Reports/flagstat",
                "$new_dir/Reports/stats",
                "$new_dir/Reports/fastqc",
                "$new_dir/VCF/GVCFs",
                "$new_dir/VCF/Complete",
                {
                    owner => 'ugpuser',
                    group => 'ugpuser'
                }
            );
        }

        if ( ! -d $new_dir ) {
            push @errors, "directory $new_dir could not be created";
            next;
        }

        # Collect all the new project_id to add to UGP table.
        push @project_info, [ $new, $new_dir, $project, $idAnalysis ];
    }

    ## Report errors
    map { say $watch->error_log($_) } @errors;

    # update UGP.check_project_id.
    my $sth = $dbh->prepare(
        "INSERT INTO UGP (check_project_id, AnalysisDataPath, project, AnalysisID, status) VALUES (?,?,?,?,?);"
    );
    foreach my $id (@project_info) {
        $sth->execute( $id->[0], $id->[1], $id->[2], $id->[3], 'analysis_created');
        $watch->update_log(
            "New Analysis: $id->[1] created for project: $id->[2]");
    }
}

## ------------------------------------------------------------ ##

sub analysis_id_name_report {

    ### from Lab table get name for analysis creation.
    my $analysis_statement =
      "select AnalysisID, AnalysisDataPath, project, status from UGP;";
    my $name_ref = $dbh->selectall_arrayref($analysis_statement);

    open( my $FH, '>', 'analysis_id_name.txt' );

    foreach my $project ( @{$name_ref} ) {
        next if ( $project->[0] eq 'NULL' );

        my $id         = $project->[0];
        my $path       = $project->[1];
        my $project_id = $project->[2];
        my $status     = $project->[3];

        $id =~ s/^/A/g;

        say $FH "$id\t$path\t$project_id\t$status";
    }
    close $FH;
}

## ------------------------------------------------------------ ##

sub _add_project_id {
    my $experiment_hash = shift;

    foreach my $exp ( keys %{$experiment_hash} ) {
        my $sth = $dbh->prepare("INSERT INTO UGP (check_project_id) VALUE(?)");
        $sth->execute($exp);
    }
}

## ------------------------------------------------------------ ##

