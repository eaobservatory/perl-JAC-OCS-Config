package JAC::OCS::Config::Instrument::WaveBand;

=head1 NAME

JAC::OCS::Config::Instrument::WaveBand - Waveband information for instrument

=head1 SYNOPSIS

    use JAC::OCS::config::Instrument::WaveBand;

    $filter = $wb->filter;

=head1 DESCRIPTION

This class represents the waveband information in a Instrument configuration
XML file.

=cut

use 5.006;
use strict;
use Carp;
use warnings;

# Overloading
use overload '""' => "_stringify_overload";

use JAC::OCS::Config::Error;
use JAC::OCS::Config::Units;
use JAC::OCS::Config::Helper qw/check_class_fatal/;

# Speed of light in m/s
use constant CLIGHT => 299792458;

our $VERSION = "1.01";

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Constructor. The constructor takes the band name
and optionally units of bandcentre, bandcentre, bandwidth and
C<Astro::Waveband> object.

    $w = JAC::OCS::Config::Header::Item->new(
        band => "B",
        waveband => $awb
    );

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    # read arguments into a hash
    my %args = @_;

    my $w = bless {
        ETAL => {},
    }, $class;

    # compatibility with XML
    for my $compat (qw/centre width/) {
        if (exists $args{$compat} && !exists $args{"band$compat"}) {
            $args{"band$compat"} = $args{$compat};
        }
    }

    # Call units before calling bandcentre
    for my $key (qw/band units label waveband bandcentre bandwidth/) {
        my $method = lc($key);
        if ($w->can($method) && exists $args{$key}) {
            $w->$method($args{$key});
        }
    }

    return $w;
}

=back

=head2 Accessor Methods

=over 4

=item B<band>

Global identifier string for this wave band linking it to a particular
receptor or sub array.

=cut

sub band {
    my $self = shift;
    if (@_) {
        $self->{Band} = shift;
    }
    return $self->{Band};
}

=item B<label>

Label of this waveband entry. For example, can be used as a FILTER name.

=cut

sub label {
    my $self = shift;
    if (@_) {
        $self->{Label} = shift;
    }
    return $self->{Label};
}

=item B<waveband>

C<Astro::WaveBand> object associated with this waveband. Note that there
is no specific C<filter> method since it is handled by C<Astro::WaveBand>.

=cut

sub waveband {
    my $self = shift;
    if (@_) {
        my $awb = check_class_fatal("Astro::WaveBand", shift(@_));
        $self->{WaveBand} = $awb;
    }
    return $self->{WaveBand};
}

=item B<bandwidth>

Retrieve and set the bandwidth. Units will be Hz by default.

    $wv->bandwidth(24E9);
    $bw = $wb->bandwidth();

An optional units option can be used if the value should be retrieved
in a different unit.

    $wb->bandwidth(45E-6, units => "m");
    $bw = $wb->bandwidth(units => "m");

Using the units option will not update the global unit since that is
only associated with the band centre. "Hz" will be the default even
if the global unit differs.

=cut

sub bandwidth {
    my $self = shift;
    my ($arg, %opt) = $self->_parse_unit_arg(0, @_);

    # Calculate input/output units
    my $inout_unit = (defined $opt{units} ? $opt{units} : "Hz");

    if (defined $arg) {
        # Always store in Hz
        my $bw = $self->_convert_to_unit($arg, $inout_unit, "Hz");
        $self->{Bandwidth} = $bw;
    }
    return $self->_convert_to_unit($self->{Bandwidth}, "Hz", $inout_unit);
}

=item B<bandcentre>

Retrieve and set the band centre. Units will be the same as those
stored in the C<units> attribute by default.

    $wv->bandcentre(24E9);
    $bw = $wb->bandcentre();

An optional units option can be used if the value should be retrieved
in a different unit.

    $wb->bandcentre(45E-6, units => "m");
    $bw = $wb->bandcentre(units => "m");

=cut

sub bandcentre {
    my $self = shift;
    my ($arg, %opt) = $self->_parse_unit_arg(1, @_);
    if (defined $arg) {
        # always update external units
        $self->units($opt{units}) if $opt{units};

        # Always store in Hz
        my $bw = $self->_convert_to_unit($arg, $opt{units}, "Hz");
        $self->{BandCentre} = $bw;
    }
    return $self->_convert_to_unit($self->{BandCentre}, "Hz", $opt{units});
}

=item B<units>

Sets or retrieves the units associated with this band centre. Defaults to "Hz"
but can be updated when setting a new value using the C<bandcentre> method.

=cut

sub units {
    my $self = shift;
    if (@_) {
        $self->{Units} = shift;
    }
    return (defined $self->{Units} ? $self->{Units} : "Hz");
}

=item B<etal>

Hash of telescope efficiency, indexed by frequency (Hz) and value
of etal.

    %etal = $wb->etal();
    $wb->etal(%etal);

If only one entry is stored, the actual frequency is not reliable.
In scalar context returns the value associated with the lowest frequency.

    $etal = $wb->etal();

A single value can be given and will be assigned a frequency.

    $wb->etal(0.85);

=cut

sub etal {
    my $self = shift;
    if (@_) {
        if (@_ == 1) {
            $self->{ETAL}->{0} = shift(@_);
        }
        else {
            %{$self->{ETAL}} = @_;
        }
    }
    if (wantarray()) {
        return %{$self->{ETAL}};
    }
    else {
        my @keys = sort keys %{$self->{ETAL}};
        return $self->{ETAL}->{$keys[0]};
    }
}

=back

=head1 GENERAL METHODS

=over 4

=item B<stringify>

Method called by the stringification overload.

=cut

sub stringify {
    my $self = shift;
    my $xml = "<waveBand ";
    for my $a (qw/band label units centre width/) {
        my $method = $a;
        $method = "band" . $method if $a =~ /centre|width/;
        my $value = $self->$method();
        next unless defined $value;
        $xml .= "$a=\"" . $value . "\" ";
    }
    $xml .= ">\n";

    # etal
    my %etal = $self->etal;
    if (scalar keys %etal == 1) {
        $xml .= " <etal>" . join(" ", values %etal) . "</etal>\n";
    }
    else {
        for my $freq (sort keys %etal) {
            $xml .= " <etal freq=\"$freq\">$etal{$freq}</etal>\n";
        }
    }

    $xml .= "</waveBand>\n";
    return $xml;
}

# forward onto stringify method
sub _stringify_overload {
    return $_[0]->stringify();
}

=back

=begin PRIVATE

=head1 PRIVATE FUNCTIONS

=over 4

=item B<_parse_unit_arg>

Given an argument list as given to an accessor method, determine
whether or not the value was given and whether or not options were given.

    ($value, %options) = $self->_parse_unit_arg($defaulting, @_);

The first argument controls units defaulting. If true, a default
units string will be supplied if no units are given, if false, no
default will be provided.

Converts

    ($val) to single value, current units (if defaulting)
    ($val, units => "x") to value and options
    (units => "x") to options and undef value

A units keys will only be guaranteed if defaulting is enabled.

=cut

sub _parse_unit_arg {
    my $self = shift;
    my $usedefs = shift;
    my %def = ($usedefs ? (units => $self->units) : ());
    if (@_ == 0) {
        return (undef, %def);
    }
    elsif (@_ == 1) {
        return ($_[0], %def);
    }
    elsif (@_ == 2) {
        return (undef, %def, @_);
    }
    elsif (@_ == 3) {
        my $val = shift;
        return ($val, %def, @_);
    }
    JAC::OCS::Config::Error::BadArgs->throw(
        "Must supply less than 4 arguments" . " (not " . @_ . ")");
}

=item B<_convert_to_unit>

Given a value, an input unit and an output unit, convert to the output
unit.

    $cvt = $self->_convert_to_unit($old, $in_unit, $out_unit);

If either in or out unit are not defined, the current unit stored in the
object will be used.

=cut

sub _convert_to_unit {
    my $self = shift;
    my ($old, $in_unit, $out_unit) = @_;
    $in_unit = $self->units unless defined $in_unit;
    $out_unit = $self->units unless defined $out_unit;

    if ($in_unit eq $out_unit) {
        return $old;
    }
    elsif (($in_unit eq 'm' && $out_unit eq 'Hz')
            || ($in_unit eq 'Hz' && $out_unit eq 'm')) {
        # keep it simple
        return (CLIGHT / $old);
    }
    else {
        JAC::OCS::Config::Error::FatalError->throw(
            "Currently too stupid to handle conversion of units $in_unit to $out_unit");
    }
}

=back

=end PRIVATE

=head1 SEE ALSO

C<Astro::WaveBand>

=head1 NOTES

A case could be made for expanding the functionality of the C<Astro::WaveBand>
class. In particular, making bandwidth available.

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

Copyright (C) 2008 Science and Technology Facilities Council.
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
