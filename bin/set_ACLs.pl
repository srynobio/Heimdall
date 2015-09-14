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

# Get base utilities
my $watch = Heimdall->new(
    config_file => 'heimdall.cfg',
    log_file    => 'watch.log'
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

