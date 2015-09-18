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

has log_dir => (
    is      => 'rw',
    builder   => 1,
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

sub _trigger_config_file {
    my $self = shift;

    my $config = $self->{config_file};
    $self->error_log("Required heimdall.cfg file not found") if ( ! -r $config );

    read_config $config => my %config;
    $self->config( \%config );
}

##------------------------------------------------------##

sub _build_log_dir {
    my $self = shift;

    my $log_dir = $self->config->{log_dir}->{log};

    foreach my $dir (@{$log_dir}) {
        chomp $dir;
        if ( -d $dir ) {
            my $watch = "$dir/watch.log";
            $self->log_file($watch);
            $self->log_dir($dir);
        }
    }
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
    exit(0);
}

##------------------------------------------------------##

sub update_log {
    my ( $self, $message ) = @_;
    $self->log_write( "[" . $self->time . "]" . " UPDATE - $message" );
}

##------------------------------------------------------##

1;
