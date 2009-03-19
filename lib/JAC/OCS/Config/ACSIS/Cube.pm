package JAC::OCS::Config::ACSIS::Cube;

=head1 NAME

JAC::OCS::Config::ACSIS::Cube - Representation of a single regridding cube

=head1 SYNOPSIS

  use JAC::OCS::Config::ACSIS::Cube;

  my $c = new JAC::OCS::Config::ACSIS::Cube;

  my @offset = $c->offset();

  my $group_centre = $c->group_centre();


=head1 DESCRIPTION

Object representing the specification for a ACSIS output cube.
This object does not parse or generate XML.

=cut

use 5.006;
use strict;
use Carp;
use warnings;

use JAC::OCS::Config::Helper qw/ check_class_fatal /;

use vars qw/ $VERSION /;

$VERSION = 1.0;

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new Cube object. Takes hash arguments, the names of which must
match accessor methods.

  $c = new JAC::OCS::Config::ACSIS::Cube( projection => 'TAN' );

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $cube = bless {
		    GroupCentre => undef,  # Astro::Coords
		    PixelSize => [],
		    Offset => [],
		    NPixels => [],
		    Projection => undef,
		    PositionAngle => undef, # Angle
		    GridFunction => undef,
		    TCSCoords => undef,
		    TruncationRadius => undef,
		    DataSourceID => undef,
		    SPWInt => undef,   # ...::Interval
		   }, $class;

  # Now run accessor methods
  my %args = @_;
  for my $key (keys %args) {
    my $method = lc($key);
    if ( $cube->can( $method ) ) {
      # Dereference arrays
      $cube->$method( (ref $args{$key} eq 'ARRAY' ? @{$args{$key}} : $args{$key} ) );
    }
  }

  return $cube;
}

=back

=head2 Accessor Methods

=over 4

=item B<group_centre>

Projection reference position for the output cube. This is I<not> the
same as the map centre of the output cube.

Stored as an C<Astro::Coords> object.  If it is not defined the
regridder will automatically adopt the telescope base position as the
tangent point.

=cut

sub group_centre {
  my $self = shift;
  if (@_) {
    my $c = shift;
    # undef is allowed
    $self->{GroupCentre} = (defined $c ? check_class_fatal( "Astro::Coords", $c) : undef );
  }
  return $self->{GroupCentre};
}

=item B<pixsize>

The X and Y pixel size in arcsec, stored as C<Astro::Coords::Angle>
objects.

  ($x, $y) = $c->pixsize;
  $c->pixsize( @xy );

=cut

sub pixsize {
  my $self = shift;
  if (@_) {
    @{$self->{PixelSize}} = check_class_fatal( "Astro::Coords::Angle",@_);
  }
  return @{ $self->{PixelSize}};
}

=item B<npix>

The number of pixels in the X and Y dimension.

  ($nx, $ny) = $c->npix;
  $c->npix( @nxy );

=cut

sub npix {
  my $self = shift;
  if (@_) {
    @{$self->{NPixels}} = @_;
  }
  return @{ $self->{NPixels}};
}

=item B<offset>

X and Y offset of the grid.

  ($dx, $dy) = $c->offset;
  $c->offset( @xy );

Units are pixels but can be floating point.

=cut

sub offset {
  my $self = shift;
  if (@_) {
    @{$self->{Offset}} = @_;
  }
  return @{ $self->{Offset}};
}

=item B<projection>

Projection used for the regridding.

=cut

sub projection {
  my $self = shift;
  if (@_) { $self->{Projection} = shift; }
  return $self->{Projection};
}

=item B<grid_function>

Regridding function to use.

=cut

sub grid_function {
  my $self = shift;
  if (@_) { $self->{GridFunction} = shift; }
  return $self->{GridFunction};
}


=item B<tcs_coord>

Whether the output cube should be in TRACKING coordinates
or AZEL.

=cut

sub tcs_coord {
  my $self = shift;
  if (@_) { $self->{TCSCoords} = shift; }
  return $self->{TCSCoords};
}

=item B<posang>

Position angle of the map, East of North.

=cut

sub posang {
  my $self = shift;
  if (@_) {
    $self->{PositionAngle} = check_class_fatal( "Astro::Coords::Angle",shift);
  }
  return $self->{PositionAngle};
}

=item B<truncation_radius>

Radius at which the gridder will no longer spread
flux. Maximum radius of convolution function in arcsec.

=cut

sub truncation_radius {
  my $self = shift;
  if (@_) { $self->{TruncationRadius} = shift; }
  return $self->{TruncationRadius};
}

=item B<fwhm>

Full width half maximum (in arcsec) of the Gaussian regridding
function.

=cut

sub fwhm {
  my $self = shift;
  if (@_) { $self->{FWHM} = shift; }
  return $self->{FWHM};
}

=item B<spw_id>

Spectral window ID that should be regridded.

=cut

sub spw_id {
  my $self = shift;
  if (@_) { $self->{DataSourceID} = shift; }
  return $self->{DataSourceID};
}

=item B<spw_interval>

Section of the spectral window sent from the reducer tasks that
should be regridded. A C<JAC::OCS::Config::Interval> object.

=cut

sub spw_interval {
  my $self = shift;
  if (@_) { 
    $self->{SPWInt} = check_class_fatal("JAC::OCS::Config::Interval",shift);
  }
  return $self->{SPWInt};
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


