#!/usr/bin/env perl

use strict;
use warnings;
use v5.10;
use Storable qw/store retrieve/;

my $limit     = 0.75;
my $statefile = '/tmp/icinga-cpu-overload.state';

my $data_diff;
my $data_old;
my $data_new = parse_data();

eval { $data_old = retrieve( $statefile ); };
# on first run there won't be a state file
if ( $@ ) {
    store $data_new, $statefile or die "Can't store %data_new to $statefile!\n";
    exit 1;
}
store $data_new, $statefile or die "Can't store %data_new to $statefile!\n";

my $alert;
for my $cpu ( sort keys %{ $data_new } ) {
    for my $key ( keys %{ $data_new->{ $cpu } } ) {
        $data_diff->{ $cpu }->{ $key } = $data_new->{ $cpu }->{ $key } - $data_old->{ $cpu }->{ $key };
    }

    my $user     = $data_diff->{ $cpu }->{user};
    my $irq      = $data_diff->{ $cpu }->{irq};
    my $softirq  = $data_diff->{ $cpu }->{softirq};
    my $system   = $data_diff->{ $cpu }->{system};
    my $nice     = $data_diff->{ $cpu }->{nice};
    my $iowait   = $data_diff->{ $cpu }->{iowait};
    my $idle     = $data_diff->{ $cpu }->{idle};

    if ( (($system + $irq + $softirq) / ($user + $nice + $iowait + $idle)) > $limit ) {
        $alert .= " $cpu";
    }
}

if ( $alert ) { say "CRITICAL - following cpus are overloaded $alert"; exit 2; }
else { say 'OK - all CPUs seem to be fine.'; }

################################################################################
sub parse_data {
################################################################################
    my $stat_ref = read_file( '/proc/stat' );
    my @raw_data = grep( /^cpu\d+/, @{ $stat_ref });
    my %data_tmp;

    for my $line ( @raw_data ) {
        chomp $line;
        my ( $cpu, $user, $nice, $system, $idle, $iowait, $irq, $softirq, $steal ) = split( /\s+/, $line );
        $data_tmp{$cpu} = {
            user    => $user,
            nice    => $nice,
            system  => $system,
            idle    => $idle,
            iowait  => $iowait,
            irq     => $irq,
            softirq => $softirq
        };
    }

    return \%data_tmp;
}

################################################################################
sub read_file {
################################################################################
    my $filename = shift;
    open(my $fh, '<:encoding(UTF-8)', $filename)
        or die "Could not open file '$filename' $!";
    my @content = <$fh>;
    return \@content;
}
