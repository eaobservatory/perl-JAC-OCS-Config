package JAC::OCS::Config::Header::Item;

=head1 NAME

JAC::OCS::Config::Header::Item - Single header item

=head1 SYNOPSIS

  use JAC::OCS::Config::Header::Item;

  $i = new JAC::OCS::Config::Header::Item( KEYWORD => "INSTRUME" );


=head1 DESCRIPTION

Representation of a single FITS header item.


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

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my %args = @_;

  my $h = bless {}, $class;

  for my $key (keys %args) {
    my $method = lc($key);
    $h->$method( $args{$key});
  }
  return $h;
}

=back

=head2 Accessor Methods

=over 4

=item B<keyword>

FITS keyword associated with this item.

=cut

sub keyword {
  my $self = shift;
  if (@_) {
    $self->{KEYWORD} = shift;
  }
  return $self->{KEYWORD};
}

=item B<type>

FITS type associated with this item.

Allowed values are CHARACTER, LOGICAL, INTEGER, FLOATING, COMMENT and HISTORY.

=cut

sub type {
  my $self = shift;
  if (@_) {
    $self->{TYPE} = shift;
  }
  return $self->{TYPE};
}

=item B<comment>

FITS comment associated with this item.

=cut

sub comment {
  my $self = shift;
  if (@_) {
    $self->{COMMENT} = shift;
  }
  return $self->{COMMENT};
}

=item B<value>

FITS value associated with this item.

If there is an external data source (ie if the C<source> attribute is
set), this value will probably be the default value to be used if the
external source is not contactable.

=cut

sub value {
  my $self = shift;
  if (@_) {
    $self->{VALUE} = shift;
  }
  return $self->{VALUE};
}

=item B<source>

Type of external data source that should be queried for the value.
Allowed values are "GLISH" and "DRAMA".

=cut

sub source {
  my $self = shift;
  if (@_) {
    $self->{SOURCE} = shift;
  }
  return $self->{SOURCE};
}

=item B<task>

Location of external data source that should be queried for the value.

=cut

sub task {
  my $self = shift;
  if (@_) {
    $self->{TASK} = shift;
  }
  return $self->{TASK};
}

=item B<param>

Parameter within external data source that should be queried for the value.

=cut

sub param {
  my $self = shift;
  if (@_) {
    $self->{PARAM} = shift;
  }
  return $self->{PARAM};
}

=item B<event>

Whether the external data source should be queried at the "START"
or "END" of the observation.

=cut

sub event {
  my $self = shift;
  if (@_) {
    $self->{EVENT} = shift;
  }
  return $self->{EVENT};
}


=back

=head1 SEE ALSO

L<JAC::OCS::Config::Header>.

L<Astro::FITS::Header::Item>.

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
