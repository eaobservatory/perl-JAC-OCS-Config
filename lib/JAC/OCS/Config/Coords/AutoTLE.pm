package JAC::OCS::Config::Coords::AutoTLE;

=head1 NAME

JAC::OCS::Config::Coords::AutoTLE - Dummy class for unknown TLE coordinates

=cut

use strict;
use warnings;

use parent qw/Astro::Coords/;

our $VERSION = '1.06';

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Construct new AutoTLE object.

    $coord = new JAC::OCS::Config::Coords::AutoTLE(name => $name);

=cut

sub new {
    my $class = shift;
    my %opt = @_;

    my $self = {
        name => $opt{'name'},
    };

    return bless $self, (ref $class) || $class;
}

=back

=head2 General Methods

=over 4

=item B<array>

Return standardized array representation, in this case mostly undef.

=cut

sub array {
    my $self = shift;

    return (
        $self->type(),
        (undef) x 10,
    );
}

=item B<type>

Return coordinate type: "AUTO-TLE".

=cut

sub type {
    my $self = shift;
    return 'AUTO-TLE';
}

=back

=head2 Accessor Methods

=over 4

=item B<bstar>

Return the bstar drag term (inverse Earth radii).

=cut

sub bstar {
    my $self = shift;
    return 0.0;
}

=item B<e>

Return the eccentricity.

=cut

sub e {
    my $self = shift;
    return 0.0;
}

=item B<epoch_day>

Return the (fractional) epoch day of the year.

=cut

sub epoch_day {
    my $self = shift;
    return 0.0;
}

=item B<epoch_year>

Return the epoch year.

=cut

sub epoch_year {
    my $self = shift;
    return 0;
}

=item B<inclination>

Return the inclination (angle object).

=cut

sub inclination {
    my $self = shift;
    return new Astro::Coords::Angle(0.0, units => 'rad');
}

=item B<mean_anomaly>

Return the mean anomaly (angle object).

=cut

sub mean_anomaly {
    my $self = shift;
    return new Astro::Coords::Angle(0.0, units => 'rad');
}

=item B<mean_motion>

Return the mean motion (revolutions per day).

=cut

sub mean_motion {
    my $self = shift;
    return 0.0;
}

=item B<raanode>

Return the RA ascending node (angle object).

=cut

sub raanode {
    my $self = shift;
    return new Astro::Coords::Angle(0.0, units => 'rad');
}

=item B<perigee>

Return the perigee (angle object).

=cut

sub perigee {
    my $self = shift;
    return new Astro::Coords::Angle(0.0, units => 'rad');
}

=back

=head1 COPYRIGHT

Copyright (C) 2014 Science and Technology Facilities Council.
All Rights Reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut

1;
