package JAC::OCS::Config::Units;

=head1 NAME

JAC::OCS::Config::Units - Units handling

=head1 SYNOPSIS

  use JAC::OCS::Config::Units;

  my $unit = new JAC::OCS::Config::Units( "MHz" );

  my $name = $unit->name;          # hertz
  my $base_unit = $unit->symbol(); # Hz
  my $prefix = $unit->prefix();    # M
  my $factor = $unit->factor;      # 6
  my $unit = $unit->unit;          # MHz

=head1 DESCRIPTION

This module parses units and decomposes them into the base
unit and multiplicative factor.

=cut


use 5.006;
use strict;
use Carp;
use warnings;

use vars qw/ $VERSION /;

$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

# PREFIXES

my %PREFIXES = (
		Z => { factor => 24, name => 'yotta' },
		E => { factor => 21, name => 'exa'},
		P => { factor => 15, name => 'peta'},
		T => { factor => 12, name => 'tera'},
		G => { factor => 9, name => 'giga'},
		M => { factor => 6, name => 'mega'},
		k => { factor => 3, name => 'kilo'},
		h => { factor => 2, name => 'hecto'},
		da => { factor => 1, name => 'deca'},
		d => { factor => -1, name => 'deci'},
		c => { factor => -2, name => 'centi'},
		'm' => { factor => -3, name => 'milli'},
		mu => { factor => -6, name => 'micro'},
		n => { factor => -9, name => 'nano'},
		p => { factor => -12, name => 'pico'},
		f => { factor => -15, name => 'femto'},
		a => { factor => -18, name => 'atto'},
		z => { factor => -21, name => 'zepto'},
		'y' => { factor => -24, name => 'yocto'},
	       );

my %BASE_UNITS = ( 
		  'm' => 'metre',
		  's' => 'second',
		  'g' => 'gram',
		  A => 'ampere',
		  K => 'kelvin',
		  mol => 'mole',
		  Cd => 'candela',
		  Hz => 'hertz',
		  N => 'newton',
		  Pa => 'pascal',
		  J => 'joule',
		  W => 'watt',
		  C => 'coulomb',
		  V => 'volt',
		  F => 'farad',
		  S => 'siemen',
		  Wb => 'weber',
		  T => 'tesla',
		  H => 'henry',
		  lm => 'lumen',
		  lx => 'lux',
		  Bq => 'becquerel',
		  Gy => 'grey',
		  Jy => 'jansky',
		  Pc => 'parsec',
		  # These are kluges for ACSIS
		  # We do not decompose these units
		  # they are used by acsis so it is easier to recognize
		  # them as valid units. For a standard module outside
		  # ACSIS these should be removed.
		  # [we could have a way to register new units that conform
		  # to SI prefixing standard]
		  'm.s-1' => 'metres per second'
		  'dBm'   => 'power ratio at 1 milliwatt 600 ohms'
		  'pixel' => 'pixel',
		  'channel' => 'channel'
		 );


=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new unit object from a string representation.

  $unit = new JAC::OCS::Config::Unit( $string );

Returns undef if the unit can not be parsed.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my ($symbol, $prefix) = _parse_unit( $_[0] );

  return undef unless defined $prefix;

  my $u = bless {
	   Prefix => $prefix,
	   Symbol => $symbol,
	  }, $class;

  return $u;
}

=back

=head2 Accessor Methods

=over 4

=item B<unit>

The actual unit (prefix and symbol).

=cut

sub unit {
  my $self = shift;
  return $self->prefix . $self->symbol;
}

=item B<symbol>

Base unit symbol associated with this unit object.

  $symbol = $u->symbol;

=cut

sub symbol {
  my $self = shift;
  return $self->{Symbol};
}

=item B<name>

The full name of the unit. Jy -> jansky.

  $name = $u->name;

=cut

sub name {
  my $self = shift;
  return $BASE_UNITS{$self->symbol};
}

=item B<prefix>

Abbreviated SI Prefix associated with this unit. Can be an empty
string if there is no prefix.

  $prefix = $u->prefix;

=cut

sub prefix {
  my $self = shift;
  return $self->{Prefix};
}

=item B<factor>

The power of ten scaling factor that should be used to convert
the number associated with this unit to a value that requires no
prefix. For example, MHz, would return a factor of 6.

=cut

sub factor {
  my $self = shift;
  my $prefix = $self->prefix;
  return 0 unless defined $prefix;
  return 0 if $prefix eq '';
  return $PREFIXES{$prefix}->{factor};
}

=item B<fullprefix>

Full name of the SI prefix. Can be an empty string if no prefix
is present. 'M' would return 'mega'.

 $pre = $u->fullprefix;

=cut

sub fullprefix {
  my $self = shift;
  my $prefix = $self->prefix;
  return '' unless defined $prefix;
  return '' if $prefix eq '';
  return $PREFIXES{$prefix}->{name};
}

=back

=cut

# INTERNAL functions

# Given a unit string, return the base unit symbol ('MHz' => 'Hz') and
# the SI prefix.

# Can return a matching symbol without a matching prefix but not vice versa.
# returns (undef,undef) if nothing is recognized.

sub _parse_unit {
  my $string = shift;

  # First look for a unit symbol
  # Since symbols can be more than one character and can match
  # multiple symbols if only looking at the last character (eg 'm' and 'lm')
  # we store all matches and then take the longest string.
  my @match = grep { $string =~ /$_$/ } keys %BASE_UNITS;

  # no match
  return (undef,undef) unless @match;

  # Get longest (most significant) match
  my $symbol = _longest( @match );

  # Error on parse, multiple matches of same length
  return (undef,undef) unless defined $symbol;

  # check to see if we do not need a prefix
  return ($symbol, '') if $symbol eq $string;

  # Now the prefix and the symbol must match the input string exactly
  @match = grep { $string eq $_.$symbol } keys %PREFIXES;

  # no match
  return ($symbol, undef) unless @match;

  # Get longest (most significant) match
  my $prefix = _longest( @match );

  return ($symbol, $prefix);
}

# return the longest string in an array. undef if multiple entries
# have same length
sub _longest {
  # do nothing if only a single argument
  return $_[0] if @_ == 1;

  # inefficient since multiple calculations of length
  # ignore problem since we do not expect more than 2 elements!
  my @sorted = sort { length($a) <=> length($b) } @_;

  if (length($sorted[-1]) != length($sorted[-2])) {
    return $sorted[-1];
  }
  return undef;
}

=head1 LIMITATIONS

Currently only recognizes SI Units (or derived units that use SI prefixes
such as Jy or parsec).

Currently does not decompose compound units (eg MW km-2 )

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
