package JAC::OCS::Config::ACSIS::SpectralWindow;

=head1 NAME

JAC::OCS::Config::ACSIS::SpectralWindow - ACSIS Spectral Window specification

=head1 SYNOPSIS

  use JAC::OCS::Config::ACSIS::SpectralWindow;

  my $spw = new JAC::OCS::Config::ACSIS::SpectralWindow;

  my %subbands = $spw->subbands;


=head1 DESCRIPTION

Object representing an ACSIS Spectral Window.  A SpectralWindow object
can refer to a single sub-band or a hybridised band.

If this is a hybrid spectral window, the sub-band information can be
obtained using the C<subbands> method.

All spectral window objects must have the following attributes:

 rest_freq_ref - Rest frequency of the band (as a string ID from LineList)
 fe_sideband   - the front end sideband
 if_coordinate - details of the if (as a IFCoord object)

If this object refers to a hybrid spectral window the following
attributes are relevant:

 subbands  - the sub band objects
 baseline_region - Array of Interval objects specifying the baseline
 baseline_fit    - Hash of fitting parameters
 line_region     - Line region of interest as array of Interval objects

A sub-band spectral window must have the shared attributed and
the following:

 bandwidth_mode
 window
 align_shift

Additionally, if a spectral window is itself just a simple subband
then all values are valid except for C<subbands>.

=cut


use 5.006;
use strict;
use Carp;
use warnings;

use JAC::OCS::Config::Helper qw/ check_class_fatal check_class_hash_fatal /;

use vars qw/ $VERSION /;

$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new spectral window object. Takes hash arguments, the names
of which must match accessor methods.

 $sw = new JAC::OCS::Config::ACSIS::SpectralWindow( line_region => \@interval);


=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $spw = bless {
		   Subbands => {},       # SpectralWindow
		   BandWidthMode => undef,
		   Window => undef,
		   AlignShift => undef,
		   RestFreqRef => undef, # Should match LineList
		   FESideband => undef,
		   IFCoordinate => undef, # IFCoord object or hash?
		   BaseLineRegion => [],  # Intervals
		   BaseLineFitParams => {},
		   LineRegion     => [],  # Intervals
		  }, $class;

  # Now run accessor methods
  my %args = @_;
  for my $key (keys %args) {
    my $method = lc($key);
    if ( $spw->can( $method ) ) {
      my $ref = ref($args{$key});

      # Dereference unblessed hashes to list
      my @args;
      if ($ref eq 'HASH') {
	@args = %{$args{$key}};
      } elsif ($ref eq 'ARRAY') {
	@args = @{$args{$key}};
      } else {
	@args = ($args{$key});
      }

      $spw->$method( @args );
    }
  }

  return $spw;
}


=back

=head2 Accessor Methods

=over 4

=item B<subbands>

Subband spectral windows that combine to make a hybrid spectral
window.  If this hash is empty, the spectral window object refers to
an actual subband. Each hash key refers to the ID of the subband
spectral window.

  %sb = $spw->subbands;

=cut

sub subbands {
  my $self = shift;
  if (@_) {
    %{$self->{Subbands}} = check_class_hash_fatal( "JAC::OCS::Config::ACSIS::SpectralWindow",@_);
  }
  return %{ $self->{Subbands}};
}

=item B<bandwidth_mode>

The mode string used to describe the correlator configuration. This
has to refer to the mode used in the ACSIS_corr XML.

Only used for non-hybrid spectral windows.

=cut

sub bandwidth_mode {
  my $self = shift;
  if (@_) { $self->{BandWidthMode} = shift; }
  return $self->{BandWidthMode};
}

=item B<window>

Windowing function to use.

Only used for non-hybrid spectral windows.

=cut

sub window {
  my $self = shift;
  if (@_) { $self->{Window} = shift; }
  return $self->{Window};
}

=item B<align_shift>

Only used for non-hybrid spectral windows to indicate the correction
required to align the subbands given the quantization in the LO2.

Units are in Hz.

=cut

sub align_shift {
  my $self = shift;
  if (@_) { $self->{AlignShift} = shift; }
  return $self->{AlignShift};
}

=item B<rest_freq_ref>

String ID that should be used to refer to an entry
in the LineList.

This does not (yet) point directly to an object in the LineList.

=cut

sub rest_freq_ref {
  my $self = shift;
  if (@_) { $self->{RestFreqRef} = shift; }
  return $self->{RestFreqRef};
}

=item B<fe_sideband>

Sideband to use in the frontend. -1 for LSB, +1 for USB.

=cut

sub fe_sideband {
  my $self = shift;
  if (@_) { $self->{FESideband} = shift; }
  return $self->{FESideband};
}

=item B<if_coordinate>

Details of the IF configuration. Must be an IFCoord object.

=cut

sub if_coordinate {
  my $self = shift;
  if (@_) {
    $self->{IFCoordinate} = check_class_fatal("JAC::OCS::Config::ACSIS::IFCoord",shift);
  }
  return $self->{IFCoordinate};
}

=item B<baseline_region>

Array of interval objects that combine to form the baseline region
that should be used for baseline subtraction.

=cut

sub baseline_region {
  my $self = shift;
  if (@_) { 
    @{$self->{BaseLineRegion}} =check_class_fatal("JAC::OCS::Config::Interval",
						  @_);
  }
  return @{$self->{BaseLineRegion}};
}

=item B<baseline_fit>

Hash of parameters describing how to fit the baseline.
Currently only understands

  function => "polynomial"
  degree   => number corresponding to polynomial order

=cut

sub baseline_fit {
  my $self = shift;
  if (@_) { 
    %{$self->{BaseLineFitParams}} = @_;
  }
  return %{$self->{BaseLineFitParams}};
}

=item B<line_region>

Array of interval objects that combine to form the line region
of interest.

=cut

sub line_region {
  my $self = shift;
  if (@_) { 
    @{$self->{LineRegion}} =check_class_fatal("JAC::OCS::Config::Interval",
					      @_);
  }
  return @{$self->{LineRegion}};
}

=item B<ishybrid>

Returns true if this is a hybridized spectral window, else returns
false.

  $ish = $spw->ishybrid;

=cut

sub ishybrid {
  my $self = shift;
  my %sb = $self->subbands;
  if (keys %sb) {
    return 1;
  } else {
    return 0;
  }
}

=item B<numcm>

Return the number of correlator modules required to implement this
mode. A hybrid mode will return the sum o

=cut

sub numcm {
  my $self = shift;
  my $total = 0;
  if ($self->ishybrid) {
    my %sb = $self->subbands;
    for my $sb (keys %sb) {
      $total += $sb->numcm;
    }
  } else {
    my $if = $self->if_coordinate;
    my $nchan = $if->nchannels;
    if ($nchan == 1024 || $nchan == 4096) {
      $total = 1;
    } elsif ($nchan == 2048 || $nchan == 8192) {
      $total = 2;
    } else {
      throw JAC::OCS::Config::Error::FatalError("Unrecognized number of channels when counting correlator modules: $nchan\n");
    }
  }
  return $total;
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


