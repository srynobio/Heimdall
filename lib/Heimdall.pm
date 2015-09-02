package Heimdall;
use strict;
use warnings;
use feature 'say';
use autodie;
use Moo;
use DBI;
use Config::Std;

##------------------------------------------------------##
##--- ATTS ---------------------------------------------##
##------------------------------------------------------##

has VERSION => (
    is => 'ro',
    default => sub { 'v0.1' },
);

has time => (
    is      => 'ro',
    default => sub {
        my $time = localtime;
        return $time;
    },
);

has config => (
    is => 'rw',
    builder => '_build_config',
);

##------------------------------------------------------##
##--- METHODS ------------------------------------------##
##------------------------------------------------------##

sub _build_config {
    my $self = shift;

    my $config = '../heimdall.cfg';
    $self->error_log("Required heimdall.cfg file not found") unless $config;

    read_config $config => my %config;
    $self->config( \%config );
}

##------------------------------------------------------##

sub dbh {
    my $self = shift;

    my $dbh = DBI->connect( 
        "DBI:mysql:database=gnomex;host=localhost",
        "srynearson", 
        "iceJihif17&", 
        { 'RaiseError' => 1 }
    );
    return $dbh;
}

##------------------------------------------------------##

sub log_write {
    my ( $self, $message ) = @_;

    open( my $FH, '>>', '../watch.log' );
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
