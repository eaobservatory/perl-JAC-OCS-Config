package JAC::OCS::Config::ACSIS::Line;

=head1 NAME

JAC::OCS::Config::ACSIS::Line - Representation of a single molecular line

=head1 SYNOPSIS

  use JAC::OCS::Config::ACSIS::Line;

  $line = new JAC::OCS::Config::ACSIS::Line( Molecule => 'CO',
                                             Transition => '3-2');

=head1 DESCRIPTION

This class represents a single molecular line and can be used in
a C<JAC::OCS::Config::ACSIS::LineList> object to represent the
different line IDs.

=cut

use 5.006;
use strict;
use Carp;
use warnings;

use JAC::OCS::Config::Error qw/ :try /;
use JAC::OCS::Config::Units;

use vars qw/ $VERSION /;

$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Construct a Line object. Recognized keys are:

  Molecule => Name of the molecule
  Transition => Molecular transition (a string)
  RestFreq => Rest frequency in Hz for this transition

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $line = bless {}, $class;

  # Read the input hash and convert all keys to lower case
  my %args = @_;
  for my $k (keys %args) {
    $args{lc($k)} = $args{$k};
  } 

  # now configure it
  for my $k (qw/ molecule transition restfreq / ) {
    if (exists $args{$k}) {
      $line->$k( $args{$k} );
    }
  }

  return $line;
}

=back

=head2 Accessor Methods

=over 4

=item B<molecule>

The name of the molecule associated with this line.

Trailing and leading space is ignored.

=cut

sub molecule {
  my $self = shift;
  if (@_) { $self->{Molecule} = _cleanup(shift) }
  return $self->{Molecule};
}

=item B<transition>

The name of the transition associated with this line.

Trailing and leading space is ignored.

=cut

sub transition {
  my $self = shift;
  if (@_) { $self->{Transition} = _cleanup(shift) }
  return $self->{Transition};
}

=item B<restfreq>

The rest frequenct (in Hz) associated with this line.

=cut

sub restfreq {
  my $self = shift;
  if (@_) { $self->{RestFreq} = shift }
  return $self->{RestFreq};
}

=back

=cut

# Routine to clean up molecule and transition strings
# to remove trailing and leading spaces.

sub _cleanup {
  my $x = shift;
  $x =~ s/^\s*//;
  $x =~ s/\s*$//;
  return $x;
}


=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

Copyright 2004-2007 Particle Physics and Astronomy Research Council.
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
