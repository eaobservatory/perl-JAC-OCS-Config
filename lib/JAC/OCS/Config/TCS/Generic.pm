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

use JAC::OCS::Config::XMLHelper qw/ get_pcdata _check_range find_children 
				    find_attr get_pcdata_multi
				    /;

use vars qw/ $VERSION @EXPORT_OK /;

$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

@EXPORT_OK = qw/ find_offsets find_pa /;

=head1 FUNCTIONS

=over 4

=item B<find_offsets>

For a given element, find all OFFSET elements that are children of
that node and return an Offset object for each. Do not look below the
current children.

 @offsets = find_offsets( $rootnode );

Returns an empty list if no offsets are found.

The number of offsets found can be verified if optional
hash arguments are provided. An exception will be thrown if the
number found is out of range. See also C<XMLHelper::find_children>.

 @offsets = find_offsets( $rootnode, min => 1, max => 4 );

Finally, an optional hash argument can be used to specify the TRACKING
system in scope for this offset if known.

 @offsets = find_offsets( $rootnode, tracking => 'J2000' );

In scalar context, returns the first element.

=cut

sub find_offsets {
  my $el = shift;
  my %args = @_;

  my $tracksys = $args{tracking};

  # look for children called OFFSET
  # but disable range check until we know how many valid ones we find
  my @matches = find_children($el, "OFFSET");

  my @offsets;
  for my $o (@matches) {
    my %xy = get_pcdata_multi( $o, "DC1", "DC2" );

    # Build up options hash for offset constructor
    my %opt = find_attr( $o, "SYSTEM","TYPE");
    $opt{tracking_system} = $tracksys if defined $tracksys;

    # Create the object
    push(@offsets, new Astro::Coords::Offset($xy{DC1}, $xy{DC2}, %opt ) );
  }

  return _check_range(\%args, "offsets", @offsets);
}

=item B<find_pa>

Find the child PA element (or elements) and return a corresponding
C<Astro::Coords::Angle> object.

 @pa = find_pa( $rootnode );

The number of position angles found can be verified if optional
hash arguments are provided. An exception will be thrown if the
number found is out of range. See also C<XMLHelper::find_children>.

 @pa = find_pa( $rootnode, min => 1, max => 4 );

In scalar context returns the first pa.

=cut

sub find_pa {
  my $el = shift;
  my %range = @_;

  # look for children called PA
  # but disable range check until we know how many valid ones we find
  my @matches = find_children( $el, "PA" );

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
  return _check_range(\%range, "position angles", @posangs);
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
