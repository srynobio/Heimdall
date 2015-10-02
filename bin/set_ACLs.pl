#!/usr/bin/env perl
# set_ACLs.pl
use strict;
use warnings;
use feature 'say';
use autodie;
use File::Find;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Heimdall;

BEGIN {
    ## needed environmental variable
    $ENV{heimdall_config} =
      '/uufs/chpc.utah.edu/common/home/u0413537/Heimdall/bin/heimdall.cfg';
}

## make object for record keeping.
my $watch = Heimdall->new( 
    config_file => $ENV{heimdall_config},
);

## get path to resources
my $resource_path = $watch->config->{main}->{resource_chpc_path};
my @dir           = $watch->config->{repository}->{lustre_repo};

my $facl_files = "$resource_path/ACL_PROJECT_FILE";
my $facl_dir   = "$resource_path/ACL_PROJECT_DIR";

find( \&set_dir_acl,  @dir );
find( \&set_file_acl, @dir );

## ----------------------------------------------------------- ##

sub set_dir_acl {
    if ( -d $_ ) {
        system("setfacl --set-file=$facl_dir $File::Find::name");
    }
}

## ----------------------------------------------------------- ##

sub set_file_acl {
    if ( -f $_ ) {
        system("setfacl --set-file=$facl_files $File::Find::name");
    }
}

## ----------------------------------------------------------- ##

