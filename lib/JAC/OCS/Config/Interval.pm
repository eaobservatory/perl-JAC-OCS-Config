package JAC::OCS::Config::Interval;

=head1 NAME

JAC::OCS::Config::Interval - Numeric intervals for OCS Configs

=head1 SYNOPSIS

    use JAC::OCS::Config::Interval;

    $i = new JAC::OCS::Config::Interval(Min => -4, Max => 20, units => 'pixels');
    $i = new JAC::OCS::Config::Interval(Min => 0);
    $i->units("pixels");

    print "$i";

=head1 DESCRIPTION

Simple class to implement a closed or open interval. This is a subclass
of C<Number::Interval> with the addition of support for an attribute
specifying the units of the numbers used to specify the interval.

=cut

use strict;
use warnings;
use Carp;

use base qw/Number::Interval/;

our $VERSION = "1.01";

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new object. Can be populated when supplied with
keys C<Max> and C<Min>.

    $i = new JAC::OCS::Config::Interval();
    $i = new JAC::OCS::Config::Interval(Max => 5, Units => 'pixels');

=cut

sub new {
    my $class = shift;
    my $i = $class->SUPER::new(@_);

    # Populate it with units
    if (@_) {
        my %args = @_;
        $i->units($args{Units}) if exists $args{Units};
    }

    return $i;
}

=back

=head2 Accessors

=over 4

=item B<units>

Units of the numbers comprising the interval.

    $u = $i->units;
    $i->units("pixels");

Can return C<undef> if no unit has been specified.

=cut

sub units {
    my $self = shift;
    if (@_) {
        $self->{Units} = shift;
    }
    return $self->{Units};
}

=back

=head1 SEE ALSO

L<Number::Interval>

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
