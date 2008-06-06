package JAC::OCS::Config::ACSIS::ProcessLink;

=head1 NAME

JAC::OCS::Config::ACSIS::ProcessLink - Representation of a glish link between two glish processes

=head1 SYNOPSIS

  use JAC::OCS::Config::ACSIS::ProcessLink;

  $ProcessLink = new JAC::OCS::Config::ACSIS::ProcessLink( from_ref => 'if_monitor',
                                                           from_event => 'if_data',
                                                           to_ref => 'sync1',
                                                           to_event => 'if_data');

=head1 DESCRIPTION

This class represents a glish links bewteen two glish processes. It can
be used in single molecular ProcessLink and can be used in a 
C<JAC::OCS::Config::ACSIS::ProcessLinks> object to represent the
different ProcessLinks.

=cut

use 5.006;
use strict;
use Carp;
use warnings;

use JAC::OCS::Config::Error qw/ :try /;

use vars qw/ $VERSION /;

$VERSION = sprintf("%d", q$Revision: 11312 $ =~ /(\d+)/);

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Construct a ProcessLink object. Recognized keys are:

  from_ref => name of the process to link from
  from_event => name of the event the from_ref will raise
  to_ref => name of the process to link to
  to_event => name of the event the to_ref will see

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $ProcessLink = bless {}, $class;

  # Read the input hash and convert all keys to lower case
  my %args = @_;
  for my $k (keys %args) {
    $args{lc($k)} = $args{$k};
  } 

  # now configure it
  for my $k (qw/ from_ref from_event to_ref to_event / ) {
    if (exists $args{$k}) {
      $ProcessLink->$k( $args{$k} );
    }
  }

  return $ProcessLink;
}

=back

=head2 Accessor Methods

=over 4

=item B<from_ref>

The name of the process to link from.

Trailing and leading space is ignored.

=cut

sub from_ref {
  my $self = shift;
  if (@_) { $self->{from_ref} = _cleanup(shift) }
  return $self->{from_ref};
}

=item B<from_event>

The name of the event the from_ref will raise.

Trailing and leading space is ignored.

=cut

sub from_event {
  my $self = shift;
  if (@_) { $self->{from_event} = _cleanup(shift) }
  return $self->{from_event};
}

=item B<to_ref>

The name of the process to link to.

Trailing and leading space is ignored.

=cut

sub to_ref {
  my $self = shift;
  if (@_) { $self->{to_ref} = _cleanup(shift) }
  return $self->{to_ref};
}

=item B<to_event>

The name of the event the to_ref will see.

Trailing and leading space is ignored.

=cut

sub to_event {
  my $self = shift;
  if (@_) { $self->{to_event} = _cleanup(shift) }
  return $self->{to_event};
}

=back

=cut

# Routine to remove trailing and leading
# spaces from a string.

sub _cleanup {
  my $x = shift;
  $x =~ s/^\s*//;
  $x =~ s/\s*$//;
  return $x;
}


=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>, Walther Zwart E<lt>w.zwart@jach.hawaii.eduE<gt>

Copyright 2004-2008 Particle Physics and Astronomy Research Council.
All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

1;
