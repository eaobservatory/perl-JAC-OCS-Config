package JAC::OCS::Config::TCS::obsArea;

=head1 NAME

JAC::OCS::Config::TCS::obsArea - Parse and modify TCS observing area

=head1 SYNOPSIS

    use JAC::OCS::Config::TCS::obsArea;

    $cfg = new JAC::OCS::Config::TCS::obsArea(File => 'obsArea.ent');
    $cfg = new JAC::OCS::Config::TCS::obsArea(XML => $xml);
    $cfg = new JAC::OCS::Config::TCS::obsArea(DOM => $dom);

    $pa = $cfg->posang;
    @offsets = $cfg->offsets;

=head1 DESCRIPTION

This class can be used to parse and modify the telescope observing area
XML.

=cut

use 5.006;
use strict;
use Carp;
use warnings;
use XML::LibXML;
use Data::Dumper;

use Astro::Coords::Angle;
use Astro::Coords::Offset;

use JAC::OCS::Config::Error;
use JAC::OCS::Config::Helper qw/
    check_class_fatal check_class/;
use JAC::OCS::Config::XMLHelper qw/
    find_children find_attr indent_xml_string/;
use JAC::OCS::Config::TCS::Generic qw/
    find_pa find_offsets pa_to_xml offset_to_xml/;

use base qw/JAC::OCS::Config::CfgBase/;

our $VERSION = "1.01";

# Allowed SCAN patterns
my @SCAN_PATTERNS = qw/
    RASTER
    DISCRETE_BOUSTROPHEDON
    CONTINUOUS_BOUSTROPHEDON
    SQUARE_PONG
    ROUNDED_PONG
    CURVY_PONG
    LISSAJOUS
    ELLIPSE
    DAISY
    CV_DAISY
/;

# hash for easy checks
my %SCAN_PATTERNS = map {$_ => undef} @SCAN_PATTERNS;

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new obsArea configuration object. An object can be created from
a file name on disk, a chunk of XML in a string or a previously created
DOM tree generated by C<XML::LibXML> (i.e. A C<XML::LibXML::Element>).

    $cfg = new JAC::OCS::Config::obsArea(File => $file);
    $cfg = new JAC::OCS::Config::obsArea(XML => $xml);
    $cfg = new JAC::OCS::Config::obsArea(DOM => $dom);

The constructor will locate the obsArea configuration in
a C<E<lt>obsAreaE<gt>> element. It will not attempt to verify that it has
a C<E<lt>TCS_CONFIGE<gt>> element as parent.

The method will die if no arguments are supplied.

=cut

sub new {
    my $self = shift;

    # Now call base class with all the supplied options
    return $self->SUPER::new(
        @_,
        $JAC::OCS::Config::CfgBase::INITKEY => {
            MAPAREA => {},
            OFFSETS => [],
            MS_OFFSETS => [],
            ELEVATIONS => [],
            SCAN => {},
            POSANG => [],
        });
}

=back

=head2 Accessor Methods

=over 4

=item B<posang>

The global position angle associated with this observing area.

    $tag = $cfg->posang;
    $cfg->posang(52.4);
    @angs = $oa->posang;
    $oa->posang(@angs);

Stored as an C<Astro::Coords::Angle> object. Multiple angles can be stored
or retrieved. In scalar context the first angle is returned.

Can be undefined if no position angle has been specified.

=cut

sub posang {
    my $self = shift;
    if (@_) {
        @{$self->{POSANG}} = map {check_class_fatal("Astro::Coords::Angle", $_)} @_;
    }
    if (wantarray) {
        return @{$self->{POSANG}};
    }
    else {
        if (@{$self->{POSANG}}) {
            return $self->{POSANG}->[0];
        }
        else {
            # do not create element zero
            return;
        }
    }
}

=item B<microsteps>

Micro steps (offsets in the focal plane) associated with the observing
area. Microsteps can be combined with C<offsets>.

See the C<offsets> method for more details. Note that the PA element is ignored
for these offsets.

Microsteps are only used in "OFFSET" obsAreas.

=cut

sub microsteps {
    my $self = shift;

    if (@_) {
        my @valid = check_class("Astro::Coords::Offset", @_);
        warnings::warnif("No micro steps passed validation.")
            unless @valid;
        @{$self->{MS_OFFSETS}} = @valid;
        $self->old_dtd(0);    # this is modern DTD
    }
    if (wantarray) {
        return @{$self->{MS_OFFSETS}};
    }
    else {
        # do not want to create an undef entry
        if (scalar @{$self->{MS_OFFSETS}}) {
            return $self->{MS_OFFSETS}->[0];
        }
        else {
            return undef;
        }
    }
}

=item B<offsets>

Offsets associated with this observing area. If more than one offset
is present, the observing area is assumed to be multiple pointings.
If one offset is present this could either indicate a single pointed
observation or the offset for a scan. The choice depends on whether
the scan area is defined or not.

    @offsets = $obs->offsets;

    $offsets = $obs->offsets;

In scalar context, returns the first offset.

If offsets are supplied, they are first validated (to make sure they
are C<Astro::Coords::Offset> objects) and then stored in the object,
overwriting previous entries.

=cut

sub offsets {
    my $self = shift;
    if (@_) {
        my @valid = check_class("Astro::Coords::Offset", @_);
        warnings::warnif("No offsets passed validation.")
            unless @valid;
        @{$self->{OFFSETS}} = @valid;
    }
    if (wantarray) {
        return @{$self->{OFFSETS}};
    }
    else {
        # do not want to create an undef entry
        if (scalar @{$self->{OFFSETS}}) {
            return $self->{OFFSETS}->[0];
        }
        else {
            return undef;
        }
    }
}



=item B<maparea>

Return details of the area to be mapped. Recognized keys are "WIDTH"
and "HEIGHT" which should be specified in arcseconds.

    %a = $obs->maparea();
    $obs->maparea(%a);

=cut

# we do not have a map area object

sub maparea {
    my $self = shift;
    if (@_) {
        my %args = @_;
        for my $k (qw/WIDTH HEIGHT/) {
            $self->{MAPAREA}->{$k} = $args{$k};
        }
    }
    return %{$self->{MAPAREA}};
}

=item B<scan>

Specification of how to scan the map area.

    %scan = $obs->scan;
    $obs->scan(%scan);

Allowed keys for hash are VELOCITY, SYSTEM, DY, TYPE, PATTERN and NTERMS.
Also, PA must be a reference to an array of C<Astro::Coords::Angle>
objects.

NTERMS is only used for CURVY_PONG patterns.

PA will be ignored by the TCS for PONG scans.

REVERSAL is not supported in newer versions of the TCS. It is
equivalent to a PATTERN of RASTER (REVERSAL=NO) or DISCRETE_BOUSTROPHEDON
(REVERSAL=YES). If REVERSAL is supplied a pattern will be inserted if
no PATTERN is provided.

=cut

# we do not have a scan specification object

sub scan {
    my $self = shift;
    if (@_) {
        my %args = @_;
        if (exists $args{REVERSAL} && !exists $args{PATTERN}) {
            $args{PATTERN} = ($args{REVERSAL}
                ? "DISCRETE_BOUSTROPHEDON"
                : "RASTER");
        }

        # Make sure it is a valid pattern
        my @extras;
        if (exists $args{PATTERN}) {
            throw JAC::OCS::Config::Error::FatalError("Supplied pattern '"
                    . $args{PATTERN}
                    . "' is not from the supported list")
                unless exists $SCAN_PATTERNS{$args{PATTERN}};

            # Curvy pong can have terms
            push(@extras, qw/NTERMS/) if $args{PATTERN} =~ /^curvy_pong$/;

            # CV daisy requires more information
            push(@extras, qw/XSTART YSTART VX VY TURN_RADIUS ACCEL/)
                if $args{PATTERN} =~ /^cv_daisy$/i;
        }

        for my $k (qw/VELOCITY SYSTEM DY TYPE PA PATTERN/, @extras) {
            # upper case patterns and type
            next unless exists $args{$k};
            my $val = $args{$k};
            $val = uc($val) if not ref $val;
            $self->{SCAN}->{$k} = $val;
        }

    }

    return %{$self->{SCAN}};
}

=item B<scan_pattern>

Return the name of the scan pattern.

    $name = $oa->scan_pattern();

Returns undef if the oberving area is not a scan.

Recognized patterns are:

=over 4

=item RASTER

(normal raster with scan reversal false)

=item DISCRETE_BOUSTROPHEDON

(raster with scan reversal true)

=item CONTINUOUS_BOUSTORPHEDON

(boustrophedon with no breaks)

=item SQUARE_PONG

=item ROUNDED_PONG

=item CURVY_PONG

=item LISSAJOUS

(curvy_pong with nterms=1)

=item ELLIPSE

=item DAISY

=item CV_DAISY

=back

If no pattern has been specified, the default is DISCRETE_BOUSTROPHEDON.

=cut

sub scan_pattern {
    my $self = shift;

    if ($self->mode eq 'area') {
        my %scan = $self->scan;

        # Absence of PATTERN means DISCRETE_BOUSTROPHEDON
        if (!exists $scan{PATTERN}
            || (exists $scan{PATTERN} && !defined $scan{PATTERN})) {
            return "DISCRETE_BOUSTROPHEDON";
        }
        else {
            return $scan{PATTERN};
        }
    }
    else {
        return undef;
    }
}

=item B<is_zenith_mode>

Indicate that this is an observation at the zenith. The particular Zenith elevation
can be controlled by using the zenith() method (Similar to skydip mode).

    $is = $oa->is_zenith_mode();
    $oa->is_zenith_mode(1);

=cut

sub is_zenith_mode {
    my $self = shift;
    if (@_) {
        $self->{IS_ZENITH_MODE} = shift;
    }
    return $self->{IS_ZENITH_MODE};
}

=item B<zenith>

Store the Zenith elevation as an Astro::Coords::Angle object. This is
similar to a skydip specification except that a single elevation is
mandated.

    $oa->zenith($el);
    $el = $oa->zenith();

An undefined value can be used to indicate a default zenith elevation.
Angles are only accessed if is_zenith_mode() is true.

Calling this method with arguments (even undefined value) will force
is_zenith_mode() to true.

=cut

sub zenith {
    my $self = shift;
    if (@_) {
        my $el = shift;
        if (defined $el) {
            my @valid = $self->_validate_elevations($el);
            $el = $valid[0];
        }
        @{$self->{ELEVATIONS}} = ($el);
        $self->old_dtd(0);    # this is modern DTD
        $self->is_zenith_mode(1);
    }

    # Avoid creating an undef entry explicitly unless one is already present
    my @el = @{$self->{ELEVATIONS}};
    return $el[0];
}

=item B<skydip>

Store or retrieve the elevations that should be visited by the telescope during the skydip.

    @el = $oa->skydip;
    $oa->skydip(@el);

Elevations should be stored as C<Astro::Coords::Angle> objects.

The elevation angles are sorted (the TCS requires that but will choose to scan in either direction).

=cut

sub skydip {
    my $self = shift;
    if (@_) {
        @{$self->{ELEVATIONS}} = $self->_validate_elevations(@_);
        $self->old_dtd(0);    # this is modern DTD
    }
    if (wantarray) {
        return @{$self->{ELEVATIONS}};
    }
    else {
        # do not want to create an undef entry
        my @el = @{$self->{ELEVATIONS}};
        return $el[0];
    }
}


=item B<skydip_mode>

Controls how the telescope moves between the elevations defined for the Skydip.
Options are "Continuous" or "Discrete".

=cut

sub skydip_mode {
    my $self = shift;
    if (@_) {
        my $mode = uc(shift);
        if ($mode ne 'CONTINUOUS' && $mode ne 'DISCRETE') {
            throw JAC::OCS::Config::Error::FatalError(
                "Skydip mode '$mode' not supported");
        }
        $self->{SKYDIP_MODE} = $mode;
    }
    return $self->{SKYDIP_MODE};
}

=item B<skydip_velocity>

Velocity in elevation of continuous skydip. Units are arcsec/sec.

=cut

sub skydip_velocity {
    my $self = shift;
    if (@_) {
        $self->{SKYDIP_VELOCITY} = shift;
    }
    return $self->{SKYDIP_VELOCITY};
}

=item B<is_sky_mode>

If true, this is a simple observing area instructing the telescope to continue tracking
its current position. It should be used when the telescope position is to be read but
where the actual position is not important.

=cut

sub is_sky_mode {
    my $self = shift;
    if (@_) {
        $self->{IS_SKY_MODE} = shift;
        $self->old_dtd(0);    # this is modern DTD
    }
    return $self->{IS_SKY_MODE};
}

=item B<mode>

Return the type of observing area that has been specified.
Can be either "sky", "zenith", "offsets", "skydip" or "area". Offsets and
micro-steps can be provided for "area" mode (only the first
of each are used).

=cut

sub mode {
    my $self = shift;

    my $mode = '';
    if ($self->is_sky_mode) {
        $mode = "sky";
    }
    elsif ($self->is_zenith_mode) {
        $mode = "zenith";
    }
    elsif ($self->maparea) {
        $mode = "area";
    }
    elsif ($self->skydip) {
        $mode = "skydip";
    }
    elsif ($self->offsets || $self->microsteps) {
        $mode = "offsets";
    }
    else {
        croak "obsArea must be sky, zenith, offsets, skydip or (map) area";
    }
    return $mode;
}

=item B<old_dtd>

If true indicates that this configuration is for an old version
of the DTD that does not support scan patterns. This controls
the stringification. This is detected by the use of the REVERSAL flag.

Note that storing microsteps or skydip information will unset this
flag.

    $oa->old_dtd(1);

Default is false.

=cut

sub old_dtd {
    my $self = shift;
    if (@_) {
        $self->{OLD_DTD} = shift;
    }
    return $self->{OLD_DTD};
}

=item B<stringify>

Convert the object back into XML.

    $xml = $obs->stringify(NOINDENT => 1);

=cut

sub stringify {
    my $self = shift;
    my %args = @_;

    my $xml = "<" . $self->getRootElementName . ">\n";

    # Version declaration
    $xml .= $self->_introductory_xml();

    # get the mode
    my $mode = $self->mode;

    # position angle for the area
    my @angs = $self->posang;
    if (@angs) {
        # force a single PA in non-area mode
        @angs = ($angs[0]) if $mode ne 'area';
        for my $pa (@angs) {
            $xml .= pa_to_xml($pa);
        }
    }

    if ($mode eq 'offsets') {
        for my $o ($self->offsets) {
            $xml .= offset_to_xml($o);
        }
        for my $m ($self->microsteps) {
            $xml .= msoffset_to_xml($m);
        }
    }
    elsif ($mode eq 'area') {
        $xml .= "<SCAN_AREA>\n";

        # Offsets
        my @o = $self->offsets;
        $xml .= offset_to_xml($o[0]) if @o;

        # Microsteps are not allowed in SCAN_AREA

        # Area definition
        my %area = $self->maparea;

        $xml .= "<AREA HEIGHT=\"$area{HEIGHT}\" WIDTH=\"$area{WIDTH}\" />\n";

        # Scan definition
        my %scan = $self->scan;

        # DTD switching
        if ($self->old_dtd) {
            my $reversal;
            if (defined $scan{PATTERN}) {
                if ($scan{PATTERN} eq 'RASTER') {
                    $reversal = "NO";
                }
                elsif ($scan{PATTERN} eq 'DISCRETE_BOUSTROPHEDON') {
                    $reversal = "YES";
                }
                else {
                    throw JAC::OCS::Config::Error::FatalError(
                        "Required to use old DTD but REVERSAL is not derivable from pattern '$scan{PATTERN}'");
                }
            }
            $scan{REVERSAL} = $reversal;
            delete $scan{PATTERN};
        }

        $xml .= "<SCAN\n";
        for my $key (keys %scan) {
            next if $key eq 'PA';
            $xml .= "      $key=\"$scan{$key}\"\n" if defined $scan{$key};
        }
        $xml .= " >\n";

        for my $pa (@{$scan{PA}}) {
            $xml .= pa_to_xml($pa);
        }

        $xml .= "</SCAN>\n";

        $xml .= "</SCAN_AREA>\n";
    }
    elsif ($mode eq 'skydip') {
        $xml .= "<SKYDIP \n";
        my $mode = $self->skydip_mode;
        $xml .= "     TYPE=\"$mode\"\n" if defined $mode;
        if (defined $mode && $mode eq 'CONTINUOUS') {
            $xml .= "     VELOCITY=\"" . $self->skydip_velocity . "\"\n"
                if defined $self->skydip_velocity;
        }
        $xml .= " >\n";

        for my $el ($self->skydip) {
            $xml .= "<ELEVATION>" . $el->degrees . "</ELEVATION>\n";
        }

        $xml .= "</SKYDIP>\n";
    }
    elsif ($mode eq 'sky') {
        $xml .= "<SKY/>\n";
    }
    elsif ($mode eq 'zenith') {
        my $el = $self->zenith();
        if (defined $el) {
            $xml .= "<ZENITH>\n";
            $xml .= "<ELEVATION>" . $el->degrees . "</ELEVATION>\n";
            $xml .= "</ZENITH>\n";
        }
        else {
            $xml .= "<ZENITH/>\n";
        }
    }
    else {
        croak "Unrecognized obsArea mode '$mode'";
    }

    $xml .= "</" . $self->getRootElementName . ">\n";

    return ($args{NOINDENT} ? $xml : indent_xml_string($xml));
}

# Helper routine to convert microsteps to xml

sub msoffset_to_xml {
    my $ms = shift;
    my ($dx, $dy) = map {$_->arcsec} $ms->offsets;
    return "<MS_OFFSET DX=\"$dx\"  DY=\"$dy\" />\n";
}

=back

=head2 Class Methods

=over 4

=item B<getRootElementName>

Return the name of the element that should be the root
node of the XML tree corresponding to the TCS obsArea config.

    @names = $tcs->getRootElementName;

=cut

sub getRootElementName {
    return ("obsArea");
}

=back

=begin __PRIVATE_METHODS__

=head2 Private Methods

=over 4

=item B<_process_dom>

Using the C<_rootnode> node referring to the top of the TCS XML,
process the DOM tree and extract all the coordinate information.

 $self->_process_dom;

Populates the object with the extracted results.

=cut

sub _process_dom {
    my $self = shift;

    # parse obsArea

    # Find any microsteps
    $self->_find_microsteps();

    # Find any offsets
    $self->_find_offsets();

    # Find any scan area
    # Noting that there will either be offsets at this level
    # or a scan area, not both
    $self->_find_scan_area();

    # Look for a skydip
    $self->_find_skydip();

    # Look for sky
    $self->_find_sky();

    # Look for Zenith
    $self->_find_zenith();

    # Find the position angle after we know the mode
    $self->_find_posang();

    return;
}

=item B<_find_posang>

Extract the position angle information if it
exists and store them in the object.

=cut

sub _find_posang {
    my $self = shift;

    # max number of angles depends on mode
    my $mode = $self->mode;

    # Scan mode can allow multiple PAs
    my @pa = find_pa(
        $self->_rootnode,
        ($mode eq 'area' ? () : (max => 1)),
        min => 0);

    # store the angle
    $self->posang(@pa) if @pa;
}

=item B<_find_offsets>

Find offsets in the top level. These will be distinct pointing centres
rather than scan area offsets.

=cut

sub _find_offsets {
    my $self = shift;
    my @offsets = find_offsets($self->_rootnode);

    # Store them
    $self->offsets(@offsets) if @offsets;
}

=item B<_find_microsteps>

Find micro steps (MS_OFFSET) elements.

Updates the object.

=cut

sub _find_microsteps {
    my $self = shift;
    my $root = $self->_rootnode;

    # Find MS_OFFSET (do not have to be any)
    my @ms = find_children($root, "MS_OFFSET");
    my @offsets;
    for my $ms (@ms) {
        my %attrs = find_attr($ms, "DX", "DY");
        push @offsets, Astro::Coords::Offset->new(
            $attrs{DX}, $attrs{DY},
            system => "FPLANE");
    }
    $self->microsteps(@offsets) if @offsets;
}

=item B<_find_scan_area>

The scan area defines the size of the region to be scan mapped. It can
include an offset, and must include an area specification, and a scan
specification.

=cut

sub _find_scan_area {
    # Not clear if we should be creating a scan area object or not
    my $self = shift;
    my $root = $self->_rootnode;

    # Find the SCAN_AREA
    my $scanarea = find_children($root, "SCAN_AREA", max => 1);
    return unless defined $scanarea;

    # We now have a scan area element
    # Find the optional offset
    my @off = find_offsets($scanarea, min => 0, max => 1);
    $self->offsets(@off) if @off;

    # Area specification
    my $area = find_children($scanarea, "AREA", min => 1, max => 1);
    my %area_info = find_attr($area, "WIDTH", "HEIGHT");
    $self->maparea(%area_info);

    # Scan specification
    my $scan = find_children($scanarea, "SCAN", min => 1, max => 1);

    # Attributes of scan
    my %scan_info = find_attr(
        $scan, "VELOCITY", "SYSTEM", "DY",
        "REVERSAL", "TYPE", "PATTERN", "NTERMS",
        "XSTART", "YSTART", "VX", "VY",
        "TURN_RADIUS", "ACCEL",
    );

    # Allowed position angles of scan
    # PONG/ELLIPSE/DAISY/LISSAJOUS do not need one
    my $minpa = 1;
    if (exists $scan_info{PATTERN}
            && $scan_info{PATTERN} =~ /(pong|liss|daisy|ellipse)/i) {
        $minpa = 0;
    }
    my @spa = find_pa($scan, min => $minpa);
    $self->scan(%scan_info, (@spa ? (PA => \@spa) : ()));

    return;
}

=item B<_find_skydip>

Look for evidence of skydip in the XML.

The object is updated.

=cut

sub _find_skydip {
    my $self = shift;
    my $root = $self->_rootnode;

    my $skydip = find_children($root, "SKYDIP", max => 1);
    return unless defined $skydip;

    my %attrs = find_attr($skydip, "TYPE", "VELOCITY");
    $self->skydip_mode($attrs{TYPE});
    $self->skydip_velocity($attrs{VELOCITY});

    # Must have 2 elements in mode SCAN, 2 or more in discrete
    my %minmax = (min => 2);
    if ($attrs{TYPE} eq 'CONTINUOUS') {
        $minmax{max} = 2;
    }

    my @el = $self->_find_elevations($skydip, %minmax);
    $self->skydip(@el);
}

=item B<_find_zenith>

Look for evidence of zenith in the XML.

The object is updated.

=cut

sub _find_zenith {
    my $self = shift;
    my $root = $self->_rootnode;

    my $zen = find_children($root, "ZENITH", max => 1);
    return unless defined $zen;

    # must have 0 or 1 elevations for Zenith
    my @el = $self->_find_elevations($zen, min => 0, max => 1);

    # force a single value which can be undef
    $self->zenith($el[0]);
}

=item B<_find_sky>

Look for evidence of SKY in the XML.

The object is updated.

=cut

sub _find_sky {
    my $self = shift;
    my $root = $self->_rootnode;

    my $sky = find_children($root, "SKY", max => 1);
    $self->is_sky_mode(1) if defined $sky;
    return;
}

=item B<_find_elevations>

Returns any elevation elements as a list of Astro::Coords::Angle objects.

    @el = $self->_find_elevations($el, min => 1, max => 2);

First argument is a node that should contain ELEVATION elements. The remaining
arguments are hash items that will be passed to find_children to constrain error
conditions.

Does not modify the object.

=cut

sub _find_elevations {
    my $self = shift;
    my $root = shift;
    my %opt = @_;
    my @elevation_nodes = find_children($root, "ELEVATION", %opt);

    my @el;
    for my $element (@elevation_nodes) {
        my $value = $element->textContent();
        next unless (defined $value and $value =~ /\S/);
        push(@el, Astro::Coords::Angle->new($value, units => 'deg'));
    }
    return @el;
}

=item B<_validate_elevations>

Verify arguments are valid elevations (Astro::Coords::Angle objects of
the correct range. The elevations are returned.

    @valid = $self->_validate_elevations(@el);

=cut

sub _validate_elevations {
    my $self = shift;
    my @valid = check_class("Astro::Coords::Angle", @_);
    warnings::warnif("No elevations passed validation.")
        unless @valid;

    # Check range
    for my $e (@valid) {
        my $deg = $e->degrees;
        throw JAC::OCS::Config::Error::FatalError(
            "Elevation must be in range 0 < el < 90 degrees (not '$deg' degrees)")
            if ($deg <= 0 || $deg > 90);
    }

    # Sort
    @valid = sort {$a->degrees <=> $b->degrees} @valid;

    return @valid;
}

=back

=end __PRIVATE_METHODS__

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

Copyright (C) 2007 - 2009 Science and Technology Facilities Council.
Copyright (C) 2004 - 2007 Particle Physics and Astronomy Research Council.
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
