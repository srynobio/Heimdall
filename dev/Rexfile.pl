use Rex -feature => ['1.3'];
use feature 'say';

logging to_file => "Heimdall.run.log";
set connection  => "SSH";

####use Cwd 'abs_path';
use Parallel::ForkManager;
use IPC::Cmd 'run';
require UGP::Tasks;
require CHPC::Tasks;

# set location of config and sqlite file.
BEGIN {
    $ENV{heimdall_config} =
        '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/heimdall.cfg';
    $ENV{sqlite_file} =
        '/scratch/ucgd/lustre/ugpuser/apps/kingspeak.peaks/ucgd_utils/trunk/data/UGP_DB.db';
}

## make object for record keeping.
my $heimdall = Heimdall->new( config_file => $ENV{heimdall_config} );

## master dir of config files.
my $configs   = $heimdall->config->{config_files}->{cfg};
my $thousand  = $heimdall->config->{backgrounds}->{thousand};
my $longevity = $heimdall->config->{backgrounds}->{longevity};

## -------------------------------------------------- ##

desc "Create bash jobs for all Process data projects.

Additional option:
    --background=<longevity or thousand> [default thousand]

";
task "Nantomics_process_data_dir", sub {
    my $command_line = shift;
    my $process_dir  = $heimdall->config->{nantomics_transfer}->{process};

    opendir( my $PROC, $process_dir )
      or Rex::Logger::info( "Can't open directory $process_dir, exiting.",
        'error' );

    foreach my $project ( readdir $PROC ) {
        chomp $project;
        next if ( $project eq '.' || $project eq '..');
        next if (is_file($project));

        ## set up the background location.
        my $background;
        my $background_name;
        my $command_background = $command_line->{background};
        if ( $command_line->{background} =~ /longevity/i ) {
            $background      = $longevity;
            $background_name = 'Longevity';
        }
        else {
            $background      = $thousand;
            $background_name = '1000Genomes';
        }

        ## data path.
        my $primary_data = "$process_dir/$project/UGP/Data/Primary_Data/";

        ## check if file exist.
        my @bam_files = glob "$primary_data/*bam";
           
        if ( !@bam_files ) {
            Rex::Logger::info( "No BAM file found in $primary_data directory", 'warn');
            next;
        }

        ## make tmp processing directory and ln to tmp.
        my $tmp_dir = "$process_dir/$project/processing_tmp";
        if ( -e $tmp_dir ) {
            Rex::Logger::info( "processing_tmp directory exist skipping.",
                "error" );
        }

        mkdir "$tmp_dir",
          owner => "u0413537",
          group => "ucgd";

        if ( !-e $tmp_dir ) {
            Rex::Logger::info( "Could not make tmp dir here: $tmp_dir", 'error');
        }

        ## symlink the bam files to tmp.
        foreach my $bam (@bam_files) {
            chomp $bam;
            ln( $bam, $tmp_dir );
        }

        ## updating config file for project.
        Rex::Logger::info("Copying and update config file for $project.");

        ## fqf_id
        my $epoch = time;
        my $fqf_id =
          'FQF-1.2.1_' . $project . '_' . $background_name . '_' . $epoch;

        my @updated_cfgs;
        opendir( my $CFG, $configs );
        foreach my $c_file ( readdir $CFG ) {
            next if ( $c_file !~ /cfg$/ );
            cp( "$configs/$c_file", $tmp_dir );

            my $data_cmd = sprintf(
                "perl -p -i -e 's|^data:|data:$tmp_dir|' $tmp_dir/$c_file");
            my $fqf_cmd = sprintf(
                "perl -p -i -e 's|^fqf_id:|fqf_id:$fqf_id|' $tmp_dir/$c_file");
            my $back_cmd = sprintf(
                "perl -p -i -e 's|^backgrounds:|backgrounds:$background|' $tmp_dir/$c_file"
            );
            # run commands. 
            `$data_cmd`;
            `$fqf_cmd`;
            `$back_cmd`;

            push @updated_cfgs, "$tmp_dir/$c_file";
        }

        my $shell = <<"EOM";
#!/bin/bash

cd $tmp_dir

## update trello
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/TrelloTalk -project $project -list data_process_active -action pipeline_start

## toGVCF
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/FQF -cfg $updated_cfgs[0] -ql 50 --run

## update trello
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/TrelloTalk -project $project -list data_process_active -action bams_complete
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/TrelloTalk -project $project -list data_process_active -action gvcf_complete

## Genotype
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/FQF -cfg $updated_cfgs[2] -ql 50 --run

## update trello
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/TrelloTalk -project $project -list data_process_active -action vcf_complete

## qc
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/FQF -cfg $updated_cfgs[1] -ql 50 --run & 
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/FQF -cfg $updated_cfgs[3] -ql 50 --run & 

## update trello
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/TrelloTalk -project $project -list data_process_active -action qc_complete
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/TrelloTalk -project $project -list data_process_active -action wham_complete
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/TrelloTalk -project $project -list data_process_active -action pipeline_finished

wait

EOM
        my $bash_file = "process/FQFrun-$project.sh";

        #my $bash_file = "$tmp_dir/FQFrun-$project.sh";
        open( my $OUT, '>', $bash_file );
        chmod 755, $bash_file;

        say $OUT $shell;
        close $OUT;
    }

};



## -------------------------------------------------- ##

desc "Create bash jobs individual Process data project.
Required option:
    --project=<UGP project name>

Additional option:
    --background=<longevity or thousand> [default thousand]

";
task "Nantomics_process_data", sub {
    my $command_line = shift;
    my $process_dir  = $heimdall->config->{nantomics_transfer}->{process};

    ## get project from command line.
    my $project = $command_line->{project};
    if ( !$project ) {
        Rex::Logger::info( "Option not given (--project=[project])", "error" );
    }

    ## set up the background location.
    my $background;
    my $background_name;
    my $command_background = $command_line->{background};
    if ( $command_line->{background} =~ /longevity/i ) {
        $background      = $longevity;
        $background_name = 'Longevity';
    }
    else {
        $background      = $thousand;
        $background_name = '1000Genomes';
    }

    ## data path.
    my $primary_data = "$process_dir/$project/UGP/Data/Primary_Data/";

    ## make tmp processing directory and ln to tmp.
    my $tmp_dir = "$process_dir/$project/processing_tmp";
    if ( -e $tmp_dir ) {
        Rex::Logger::info( "processing_tmp directory exist skipping.", "error");
    }

    mkdir "$tmp_dir",
      owner => "u0413537",
      group => "ucgd";

    if ( !-e $tmp_dir ) {
        Rex::Logger::info( "Could not make tmp dir here: $tmp_dir", "error" );
    }

    ## check if file exist.
    my @bam_files = glob "$primary_data/*bam";

    if ( !@bam_files ) {
        Rex::Logger::info( "No BAM file found in $primary_data directory",
            "error" );
    }

    ## symlink the file to tmp.
    foreach my $bam (@bam_files) {
        chomp $bam;
        ln( $bam, $tmp_dir );
    }

    ## updating config file for project.
    Rex::Logger::info("Copying and update config file for $project.");

    ## fqf_id
    my $epoch = time;
    my $fqf_id =
      'FQF-1.2.1_' . $project . '_' . $background_name . '_' . $epoch;

    my @updated_cfgs;
    opendir( my $CFG, $configs );
    foreach my $c_file ( readdir $CFG ) {
        next if ( $c_file !~ /cfg$/ );
        cp( "$configs/$c_file", $tmp_dir );

        my $data_cmd =
          sprintf("perl -p -i -e 's|^data:|data:$tmp_dir|' $tmp_dir/$c_file");
        my $fqf_cmd = sprintf(
            "perl -p -i -e 's|^fqf_id:|fqf_id:$fqf_id|' $tmp_dir/$c_file");
        my $back_cmd = sprintf(
            "perl -p -i -e 's|^backgrounds:|backgrounds:$background|' $tmp_dir/$c_file"
        );

        # run commands.
        `$data_cmd`;
        `$fqf_cmd`;
        `$back_cmd`;

        push @updated_cfgs, "$tmp_dir/$c_file";
    }

    my $shell = <<"EOM";
#!/bin/bash

cd $tmp_dir

## update trello
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/TrelloTalk -project $project -list data_process_active -action pipeline_start

## toGVCF
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/FQF -cfg $updated_cfgs[0] -ql 50 --run

## update trello
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/TrelloTalk -project $project -list data_process_active -action bams_complete
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/TrelloTalk -project $project -list data_process_active -action gvcf_complete

## Genotype
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/FQF -cfg $updated_cfgs[2] -ql 50 --run

## update trello
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/TrelloTalk -project $project -list data_process_active -action vcf_complete

## qc
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/FQF -cfg $updated_cfgs[1] -ql 50 --run & 
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/FQF -cfg $updated_cfgs[3] -ql 50 --run & 

## update trello
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/TrelloTalk -project $project -list data_process_active -action qc_complete
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/TrelloTalk -project $project -list data_process_active -action wham_complete
/uufs/chpc.utah.edu/common/home/u0413537/MasterVersions/FQF/bin/TrelloTalk -project $project -list data_process_active -action pipeline_finished

wait

EOM

    my $bash_file = "process/FQFrun-$project.sh";
    #my $bash_file = "$tmp_dir/FQFrun-$project.sh";
    open( my $OUT, '>', $bash_file );
    chmod 755, $bash_file;

    say $OUT $shell;
    close $OUT;
};

## -------------------------------------------------- ##

desc "Will run all bash jobs in process dir

Additional option:
    --cpu=<INT> [default 5]

";
task "Process_bash_jobs", sub {
    my $command_line = shift;

    my $cpu = $command_line->{cpu} || 5;
    my $pm = Parallel::ForkManager->new($cpu);

    my $process_dir = $heimdall->{config}->{process_dir}->{process};
    opendir( my $DIR, $process_dir )
      or Rex::Logger::info( "Can't open $process_dir directory...exiting.",
        'error' );

    foreach my $sh ( readdir $DIR ) {
        next if ( $sh eq '.' || $sh eq '..' );
        Rex::Logger::info( "Running shell script $sh.", 'warn' );

        $pm->start and next;

        my $cmd = "$process_dir/$sh";
        my ( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) =
          run( command => $cmd, verbose => 0 );

        if ($success) {
            say "cmd completed: $cmd";
            map { say "Buffer: $_" } @$full_buf;
        }
        else {
            say "error results: $error_message";
            map { say "Error Buffer: $_" } @$full_buf;
        }

        $pm->finish;
    }
    $pm->wait_all_children;
};

## -------------------------------------------------- ##

sub timestamp {
    my $self = shift;
    my $time = localtime;
    return $time;
}

## -------------------------------------------------- ##

1;

