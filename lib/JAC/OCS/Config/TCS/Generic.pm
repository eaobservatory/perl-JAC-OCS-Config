package JAC::OCS::Config::TCS::Generic;

=head1 NAME

JAC::OCS::Config::TCS::Generic - Helper functions for TCS XML parsing

=head1 SYNOPSIS

  use JAC::OCS::Config::TCS::Generic;

  @offsets = find_offsets( $rootnode );


=head1 DESCRIPTION

Helper routines, specific to TCS XML, to aid the handling of TCS XML
components. Code for converting OFFSET elements to Offset objects is
required for handling base positions, observing areas and scan offsets
so this code is reused rather than duplicated.

Routines useful for all parsers will be found in
C<JAC::OCS::Config::CfgBase>.

This package is not a class.

=cut


use 5.006;
use strict;
use Carp;
use warnings;
use XML::LibXML;
use Data::Dumper;

use Astro::Coords::Offset;

use JAC::OCS::Config::XMLHelper qw/ get_pcdata /;

use vars qw/ $VERSION /;

$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 FUNCTIONS

=over 4

=item B<find_offsets>

For a given element, find all OFFSET elements that are children of
that node and return an Offset object for each. Do not look below the
current children.

 @offsets = find_offsets( $rootnode );

Returns an empty list if no offsets are found.

An optional second argument can be used to specify the TRACKING
system in scope for this offset if known.

 @offsets = find_offsets( $rootnode, 'J2000' );

=cut

sub find_offsets {
  my $el = shift;
  my $tracksys = shift;

  # look for children called OFFSET
  my @matches = $el->getChildrenByTagName( 'OFFSET' );

  my @offsets;
  for my $o (@matches) {
    my $dx = get_pcdata( $o, 'DC1');
    my $dy = get_pcdata( $o, 'DC1');
    my $system = $o->getAttribute('SYSTEM');
    my $type = $o->getAttribute('TYPE');

    # Build up options hash for offset constructor
    my %opt = ( system => $system, projection => $type );
    $opt{tracking_system} = $tracksys if defined $tracksys;

    # Create the object
    push(@offsets, new Astro::Coords::Offset($dx, $dy, %opt ) );
  }

  return @offsets;
}

=item B<find_pa>

Find the child PA element (or elements) and return a corresponding
C<Astro::Coords::Angle> object.

 @pa = find_pa( $rootnode );

=cut

sub find_pa {
  my $el = shift;

  # look for children called PA
  my @matches = $el->getChildrenByTagName( 'PA' );

  # Now iterate over all matches
  my @posangs;
  for my $o (@matches) {
    my $posang = $o->firstChild;
    next unless $posang;
    push(@posangs, new Astro::Coords::Angle( $posang->toString,
					     units => 'deg',
					     range => 'PI',
					   ) );
  }
  return @posangs;
}


=back

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

Copyright 2004 Particle Physics and Astronomy Research Council.
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
