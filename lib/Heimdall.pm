package Heimdall;
use strict;
use warnings;
use feature 'say';
use autodie;
use Moo;
use DBI;

## Logging
## cfg file.
open(my $LOG, '>>', '../watch.log');

##------------------------------------------------------##
##--- ATTS ---------------------------------------------## 
##------------------------------------------------------##

has time => (
    is => 'ro',
    default => sub {
        my $time = localtime;
        return $time;
    },
);

has dbh => (
    is => 'rw',
    builder => '_build_dbh',
);

##------------------------------------------------------##
##--- METHODS ------------------------------------------##
##------------------------------------------------------##

sub _build_dbh {
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

sub info_log {
    my ($self, $message) = @_;
    say $LOG "[" . $self->time . "]" . " INFO - $message";
}

##------------------------------------------------------##

sub error_log {
    my ($self, $message) = @_;
    say $LOG "[" . $self->time . "]" . " ERROR - $message";
}

##------------------------------------------------------##

sub update_log {
    my ($self, $message) = @_;
    say $LOG "[" . $self->time . "]" . " UPDATE - $message";
} 

##------------------------------------------------------##

1;
