package JAC::OCS::Config::ACSIS::IFCoord;

=head1 NAME

JAC::OCS::Config::ACSIS::IFCoord - IF specification in spectral window

=head1 SYNOPSIS

 use JAC::OCS::Config::ACSIS::IFCoord;



=head1 DESCRIPTION

Details of the IF frequency, reference channel, channel width and
number of channles for a subband. The class name derives from the
XML element name grouping this information in the Spectral Window
XML.

=cut

use 5.006;
use strict;
use Carp;
use warnings;

use vars qw/ $VERSION /;

$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

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

  my $if = bless {
		    IFFreq => undef,
		    RefChannel => undef,
		    ChannelWidth => undef,
		    NChannels => undef,
		   }, $class;

  # Now run accessor methods
  my %args = @_;
  for my $key (keys %args) {
    my $method = lc($key);
    if ( $if->can( $method ) ) {
      # Dereference arrays
      $if->$method( $args{$key} );
    }
  }

  return $if;
}

=back

=head2 Accessor Methods

=over 4

=item B<if_freq>

The IF frequency (in Hz).

=cut

sub if_freq {
  my $self = shift;
  if (@_) {
    $self->{IFFreq} = shift;
  }
  return $self->{IFFreq};
}

=item B<ref_channel>

The reference channel in the subband.

=cut

sub ref_channel {
  my $self = shift;
  if (@_) {
    $self->{RefChannel} = shift;
  }
  return $self->{RefChannel};
}

=item B<channel_width>

The channel width in Hz.

=cut

sub channel_width {
  my $self = shift;
  if (@_) {
    $self->{ChannelWidth} = shift;
  }
  return $self->{ChannelWidth};
}

=item B<nchannels>

The number of channels in the subband.

=cut

sub nchannels {
  my $self = shift;
  if (@_) {
    $self->{NChannels} = shift;
  }
  return $self->{NChannels};
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

