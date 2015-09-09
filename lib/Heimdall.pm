package Heimdall;
use strict;
use warnings;
use feature 'say';
use autodie;
use Moo;
use DBI;
use Config::Std;
use Cwd 'abs_path';

##------------------------------------------------------##
##--- ATTS ---------------------------------------------##
##------------------------------------------------------##

has VERSION => (
    is      => 'ro',
    default => sub { 'v0.1' },
);

has time => (
    is      => 'ro',
    default => sub {
        my $time = localtime;
        return $time;
    },
);

has log_file => ( is => 'rw' );

has config_file => (
    is      => 'rw',
    trigger => 1,
);

has config => ( is => 'rw' );

##------------------------------------------------------##
##--- METHODS ------------------------------------------##
##------------------------------------------------------##

#sub BUILDARGS {
#    my $self = shift;
#
#    ## this is done so it can be called from
#    ## anywhere.
#    my $path = abs_path($0);
#    $path =~ s/(.*Heimdall)(.*$)/$1/;
#
#    my $log = $path . "/watch.log";
#    my $cfg = $path . "/heimdall.cfg";
#
#    return {
#        config_file => $cfg,
#        log_file    => $log,
#    };
#}

##------------------------------------------------------##

sub _trigger_config_file {
    my $self = shift;

    my $config = $self->{config_file};
    $self->error_log("Required heimdall.cfg file not found") if ( !-r $config );

    read_config $config => my %config;
    $self->config( \%config );
}

##------------------------------------------------------##

sub dbh {
    my $self = shift;

    my $dbh = DBI->connect( "DBI:mysql:database=gnomex;host=localhost",
        "srynearson", "iceJihif17&", { 'RaiseError' => 1 } );
    return $dbh;
}

##------------------------------------------------------##

sub log_write {
    my ( $self, $message ) = @_;

    open( my $FH, '>>', $self->log_file );
    say $FH $message;
    close $FH;
}

##------------------------------------------------------##

sub info_log {
    my ( $self, $message ) = @_;
    $self->log_write( "[" . $self->time . "]" . " INFO - $message" );
}

##------------------------------------------------------##

sub error_log {
    my ( $self, $message ) = @_;
    $self->log_write( "[" . $self->time . "]" . " ERROR - $message" );
}

##------------------------------------------------------##

sub update_log {
    my ( $self, $message ) = @_;
    $self->log_write( "[" . $self->time . "]" . " UPDATE - $message" );
}

##------------------------------------------------------##

1;
