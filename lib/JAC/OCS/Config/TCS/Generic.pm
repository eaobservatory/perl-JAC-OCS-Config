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

use Math::Trig qw/ rad2deg /;
use Astro::Coords::Offset;

use JAC::OCS::Config::XMLHelper qw/ get_pcdata _check_range find_children 
				    find_attr get_pcdata_multi
				    /;

use vars qw/ $VERSION @EXPORT_OK /;

$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

@EXPORT_OK = qw/ find_offsets find_pa pa_to_xml offset_to_xml coords_to_xml /;

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

=item B<pa_to_xml>

Convert an C<Astro::Coords::Angle> object to TCS XML.

 $xml = pa_to_xml( $ang );

=cut

sub pa_to_xml {
  my $ang = shift;
  my $deg = $ang->degrees;
  # limit precision and clean up
  $deg = _clean_number(sprintf("%.2f",$deg));
  my $xml = "<PA>".$deg."</PA>\n";
}

=item B<offset_to_xml>

Convert an C<Astro::Coords::Offset> object to TCS XML.

 $xml = offset_to_xml( $off );

=cut

sub offset_to_xml {
  my $off = shift;
  my $xml = "";
  my $sys = $off->system;
  my $proj = $off->projection;

  $xml .= "<OFFSET ";
  $xml .= "SYSTEM=\"$sys\" " if defined $sys;
  $xml .= "TYPE=\"$proj\" " if defined $proj;
  $xml .= ">\n";

  my @offsets = $off->offsets();
  $xml .= "  <DC1>$offsets[0]</DC1>\n";
  $xml .= "  <DC2>$offsets[1]</DC2>\n";
  $xml .= "</OFFSET>\n";
  return $xml;
}

=item B<coords_to_xml>

Convert C<Astro::Coords> object to TCS XML.
Includes the <target> tags.

=cut

sub coords_to_xml {
  my $c = shift;
  my $type = $c->type;
  my $name = $c->name;
  $name = "" if !defined $name;

  my $xml = "<target>\n";
  $xml .= "  <targetName>$name</targetName>\n";

  if ($type eq "PLANET") {
    # namedSystem
    $xml .= "  <namedSystem type=\"major\" />\n";
  } elsif ($type eq 'RADEC' || $type eq 'FIXED') {
    # spherSystem
    # Currently there are only two coordinate systems supported
    # by Astro::Coords that make any sense: J2000 and AZEL
    my $sys;
    if ($type eq 'RADEC') {
      $sys = "J2000";
      $xml .= "  <spherSystem SYSTEM=\"$sys\">\n";
      $xml .= "    <c1>". $c->ra2000(format => 's')."</c1>\n";
      $xml .= "    <c2>". $c->dec2000(format => 's')."</c2>\n";

      $xml .= "    <parallax>". $c->parallax ."</parallax>\n"
	if defined $c->parallax;

      # proper motions in arcsec
      my @pm = $c->pm;
      if (@pm) {
	$xml .= "    <epoch>2000.0</epoch>\n";
	$xml .= "    <pm1 units=\"arcsec-year\">".$pm[0]."</pm1>\n";
	$xml .= "    <pm2 units=\"arcsec-year\">".$pm[1]."</pm2>\n";
      }

      # Radial Velocity goes here!

    } elsif ($type eq 'FIXED') {
      $sys = "AZEL";
      $xml .= "  <spherSystem SYSTEM=\"$sys\">\n";
      $xml .= "    <c1>". $c->az(format => 's')."</c1>\n";
      $xml .= "    <c2>". $c->el(format => 's')."</c2>\n";
    } else {
      croak "Completely impossible - type neither RADEC nor FIXED but $type\n";
    }
    $xml .= "  </spherSystem>\n";
  } elsif ($type eq 'ELEMENTS') {
    # conicSystem
    $xml .= "  <conicSystem>\n";
    my %el = $c->elements;

    my $type;
    if (exists $el{DM}) {
      $type = 'major';
    } elsif (exists $el{AORL}) {
      $type = 'minor';
    } elsif (exists $el{EPOCHPERIH}) {
      $type = 'comet';
    } else {
      croak "Unable to determine element type!";
    }

    $xml .= "    <epoch>$el{EPOCH}</epoch>\n";
    $xml .= "    <inclination>".rad2deg($el{ORBINC})."</inclination>\n";
    $xml .= "    <anode>".rad2deg($el{ANODE})."</anode>\n";
    $xml .= "    <perihelion>".rad2deg($el{PERIH})."</perihelion>\n";
    $xml .= "    <aorq>$el{AORQ}</aorq>\n";
    $xml .= "    <e>$el{E}</e>\n";
    $xml .= "    <epochperih>$el{EPOCHPERIH}</epochperih>\n"
      if exists $el{EPOCHPERIH};
    $xml .= "    <LorM>".rad2deg($el{AORL})."</LorM>\n"
      if exists $el{AORL};
    $xml .= "    <n>".rad2deg($el{DM})."</n>\n" if exists $el{DM};

    $xml .= "  </conicSystem>\n";

  } else {
    croak "Do not yet know how to xml-ify coords of type $type";
  }
  $xml .= "</target>\n";

  return $xml;
}

=back

=begin __PRIVATE__

=head2 Private Functions

=over 4

=item B<_clean_number>

Remove trailing zeroes and a trailing decimal point from numbers.
Convert "15.00" to "15" and "15.30" to "15.3".

=cut

sub _clean_number {
  my $num = shift;
  $num =~ s/0$//g; # strip trailing zeroes
  $num =~ s/\.$//; # and trailing decimal point
  return $num;
}

=back

=end __PRIVATE__

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
