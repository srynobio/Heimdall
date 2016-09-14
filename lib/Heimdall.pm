package Heimdall;
use strict;
use warnings;
use feature 'say';
use Moo;
use Config::Std;
use Cwd;

##------------------------------------------------------##
##--- ATTS ---------------------------------------------##
##------------------------------------------------------##

has VERSION => (
    is      => 'ro',
    default => sub { '0.0.1' },
);

has time => (
    is      => 'ro',
    default => sub {
        my $time = localtime;
        return $time;
    },
);

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
    $self->ERROR("Required heimdall.cfg file not found") if ( !-r $config );

    read_config $config => my %config;
    $self->config( \%config );
}

##------------------------------------------------------##

sub log_write {
    my ( $self, $message ) = @_;
    my $log_file = $self->config->{log_file}->{file};

    open( my $OUT, '>>', $log_file );
    say $OUT $message;
    close $OUT;
}

##------------------------------------------------------##

sub INFO {
    my ( $self, $message ) = @_;
    $self->log_write( "[" . $self->time . "]" . " INFO - $message" );
}

##------------------------------------------------------##

sub ERROR {
    my ( $self, $message ) = @_;
    $self->log_write( "[" . $self->time . "]" . " ERROR - $message" );
    exit(0);
}

##------------------------------------------------------##

sub UPDATE {
    my ( $self, $message ) = @_;
    $self->log_write( "[" . $self->time . "]" . " UPDATE - $message" );
}

##------------------------------------------------------##

## Carson created
## Allows you to run cmd as ugpuser
## not tested.

#sub ugpuser_cmd {
#    my ($self, $command) = @_;
#
#    my $cwd = getcwd;
#    open( my $TERM, '| sudo /bin/su - ugpuser' ) or return $? = -1;
#    print $TERM "cd $cwd\n";
#    print $TERM "$command\n";
#    print $TERM "exit \$?\n";
#    close($TERM);
#
#    $? = -1 if ( $? >> 8 == 127 || $? >> 8 == 126 );    #can't run
#
#    return $?;
#}

##------------------------------------------------------##

1;
