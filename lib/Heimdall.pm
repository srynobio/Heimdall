package Heimdall;
use strict;
use warnings;
use feature 'say';
use Moo;
use Config::Std;
use Cwd 'abs_path';
use Email::Stuffer;

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
    $self->error_log("Required heimdall.cfg file not found") if ( !-r $config );

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

sub ucgd_members_mail {
    my ( $self, $message ) = @_;

    my $body = <<"EOM";

UCGD status message sent to all UCGD members.

@{$message}

EOM

my $stuffer = Email::Stuffer->new();
$stuffer->from('shawn.rynearson@gmail.com')
    ->subject("UCGD members message")
    ->to('shawn.rynearson@gmail.com')
    ->text_body($body)
    ->send;
}

##------------------------------------------------------##

1;
