package JAC::OCS::Config::ACSIS::CubeList;

=head1 NAME

JAC::OCS::Config::ACSIS::CubeList - Parse and modify OCS ACSIS cube configurations

=head1 SYNOPSIS

    use JAC::OCS::Config::ACSIS::CubeList;

    $cfg = new JAC::OCS::Config::ACSIS::CubeList(DOM => $dom);

=head1 DESCRIPTION

This class can be used to parse and modify the ACSIS cube configuration
information present in the C<cube_list> element of an OCS configuration.

Fundamentally, contains an array of cube objects.

=cut

use 5.006;
use strict;
use Carp;
use warnings;
use warnings::register;
use Astro::Coords::Angle;

use JAC::OCS::Config::Error qw/:try/;

use JAC::OCS::Config::ACSIS::Cube;

# Parsing spherSystem
use JAC::OCS::Config::TCS::BASE;
use JAC::OCS::Config::TCS::Generic qw/coords_to_xml/;

use JAC::OCS::Config::XMLHelper qw/
    find_attr find_attrs_and_pcdata find_children find_attr_child
    get_this_pcdata get_pcdata find_range interval_to_xml indent_xml_string/;
use JAC::OCS::Config::Helper qw/check_class_hash_fatal/;

use base qw/JAC::OCS::Config::CfgBase/;

our $VERSION = "1.01";

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new CubeList configuration object. An object can be created from
a file name on disk, a chunk of XML in a string or a previously created
DOM tree generated by C<XML::LibXML> (i.e. A C<XML::LibXML::Element>).

    $cfg = new JAC::OCS::Config::ACSIS::CubeList(File => $file);
    $cfg = new JAC::OCS::Config::ACSIS::CubeList(XML => $xml);
    $cfg = new JAC::OCS::Config::ACSIS::CubeList(DOM => $dom);

The method will die if no arguments are supplied.

=cut

sub new {
    my $self = shift;

    # Now call base class with all the supplied options +
    # extra initialiser
    return $self->SUPER::new(
        @_,
        $JAC::OCS::Config::CfgBase::INITKEY => {
            CUBES => {},
        });
}

=back

=head2 Accessor Methods

=over 4

=item B<cubes>

Hash of C<JAC::OCS::Config::ACSIS::Cube> objects. Values should be
JAC::OCS::Config::ACSIS::Cube objects. Keys are the cube ID to use in
the list.

=cut

sub cubes {
    my $self = shift;
    if (@_) {
        %{$self->{CUBES}} = check_class_hash_fatal("JAC::OCS::Config::ACSIS::Cube", @_);
    }
    return %{$self->{CUBES}};
}

=item B<stringify>

Create XML representation of object.

=cut

sub stringify {
    my $self = shift;
    my %args = @_;

    my $xml = "<" . $self->getRootElementName . ">\n";

    # Version declaration
    $xml .= $self->_introductory_xml();

    my %cubes = $self->cubes;

    # loop over all cubes
    for my $k (sort keys %cubes) {
        my $c = $cubes{$k};
        $xml .= "<cube id=\"$k\">\n";

        # Group centre (optional)
        my $gc = $c->group_centre();
        if (defined $gc && $c->tcs_coord ne 'AZEL') {
            $xml .= "<group_centre>\n";

            # use simple format
            $xml .= coords_to_xml($gc, 1);

            $xml .= "</group_centre>\n";
        }

        # Pixel size (arcsec)
        my @pixsize = $c->pixsize;
        if (@pixsize) {
            $xml .= "<x_pix_size units=\"arcsec\">"
                . $pixsize[0]->arcsec
                . "</x_pix_size>\n";
            $xml .= "<y_pix_size units=\"arcsec\">"
                . $pixsize[1]->arcsec
                . "</y_pix_size>\n";
        }

        # Data source
        $xml .= "<data_source>\n";
        $xml .= "<spw_ref ref=\"" . $c->spw_id . "\"/>\n";
        $xml .= interval_to_xml($c->spw_interval);
        $xml .= "</data_source>\n";

        # Pixel Offsets
        my @offset = $c->offset;
        $xml .= "<x_offset>$offset[0]</x_offset>\n";
        $xml .= "<y_offset>$offset[1]</y_offset>\n";

        # Size of map
        my @npix = $c->npix;
        $xml .= "<x_npix>$npix[0]</x_npix>\n";
        $xml .= "<y_npix>$npix[1]</y_npix>\n";

        # projection and gridder
        $xml .= "<projection type=\"" . $c->projection . "\" />\n";
        $xml .= "<grid_function type=\"" . $c->grid_function . "\" />\n";

        if ($c->grid_function ne 'TopHat') {
            $xml .= "<FWHM>" . $c->fwhm . "</FWHM>\n";
        }

        # optional position angle
        my $pa = $c->posang();
        if (defined $pa) {
            $xml .= "<pos_ang>" . $pa->degrees . "</pos_ang>\n";
        }

        # TCS coordinates
        $xml .= "<tcs_coord type=\"" . $c->tcs_coord . "\" />\n";

        # The gridder needs a non-zero value for smoothing radius
        # even if it doesn't really use it....
        my $rad = $c->truncation_radius;
        if (!defined $rad || $rad == 0) {
            $rad = sqrt($pixsize[0]->arcsec**2 + $pixsize[1]->arcsec**2) / 2;
            if ($c->grid_function ne 'TopHat') {
                warnings::warnif(
                    "No smoothing radius specified. Defaulting to 1 pixel (=$rad arcsec)\n");
            }
        }

        # Note that the name is still smoothing radius
        # even though that is a misnomer
        $xml .= "<smoothing_rad>" . $rad . "</smoothing_rad>\n";

        $xml .= "</cube>\n";
    }

    $xml .= "</" . $self->getRootElementName . ">\n";

    return ($args{NOINDENT} ? $xml : indent_xml_string($xml));
}

=back

=head2 Class Methods

=over 4

=item B<getRootElementName>

Return the name of the _CONFIG element that should be the root
node of the XML tree corresponding to the ACSIS cube config.

    @names = $h->getRootElementName;

=cut

sub getRootElementName {
    return ("cube_list");
}

=back

=begin __PRIVATE_METHODS__

=head2 Private Methods

=over 4

=item B<_process_dom>

Using the C<_rootnode> node referring to the top of the XML tree,
process the DOM tree and extract all the coordinate information.

    $self->_process_dom;

Populates the object with the extracted results.

=cut

sub _process_dom {
    my $self = shift;

    # Find all the header items
    my $el = $self->_rootnode;

    # need to get all the cube elements
    my @cxml = find_children($el, "cube", min => 1);

    my %cubes;

    # Now extract information from each cube
    for my $c (@cxml) {
        my $id = find_attr($c, "id");

        # TCS coordinate system for regridding (AZEL or TRACKING)
        my $tcs_coord = find_attr_child($c, "tcs_coord", "type");

        # group centre may or may not exist (we can work this out
        # from the tcs_coord.
        my $gcen = find_children($c, "group_centre", max => 1);
        my $coords;
        if ($gcen) {
            # mandatory spherSystem
            # but we should use the TCS XML parser to decode this
            # and convert it to Astro::Coords object
            # This is all done already in
            #    JAC::OCS::Config::TCS::BASE->_extract_coord_info
            # This could get hairy. For now, just use it and hope the
            # interface doesn't change. This could be factored out into
            # a standard TCS/Generic helper function since it is a class method
            $coords = JAC::OCS::Config::TCS::BASE->_extract_coord_info($gcen);
        }

        # pixel size
        my %attr;
        (my $x_pix_size, %attr) = find_attrs_and_pcdata($c, "x_pix_size");
        my $x_pix_size_units = (defined $attr{units} ? $attr{units} : '');
        (my $y_pix_size, %attr) = find_attrs_and_pcdata($c, "y_pix_size");
        my $y_pix_size_units = (defined $attr{units} ? $attr{units} : '');

        $x_pix_size = new Astro::Coords::Angle($x_pix_size, units => $x_pix_size_units);
        $y_pix_size = new Astro::Coords::Angle($y_pix_size, units => $y_pix_size_units);

        # offset
        my $x_offset = get_pcdata($c, "x_offset");
        my $y_offset = get_pcdata($c, "y_offset");

        # Number of pixels
        my $x_npix = get_pcdata($c, "x_npix");
        my $y_npix = get_pcdata($c, "y_npix");

        # projection
        my $projection = find_attr_child($c, "projection", "type");

        # regridding function
        my $grid_function = find_attr_child($c, "grid_function", "type");

        # position angle (should probably be PA)
        my $pa = get_pcdata($c, "pos_ang");
        $pa = new Astro::Coords::Angle($pa, units => 'deg') if defined $pa;

        # Gaussian FWHM
        my $fwhm = get_pcdata($c, "FWHM");

        # Smoothing radius (in arcsec) (need to allow truncation_rad or smoothing_rad)
        my $trun_rad = get_pcdata($c, "smoothing_rad");
        if (!defined $trun_rad) {
            $trun_rad = get_pcdata($c, "truncation_rad");
        }

        # data source
        my $dsrc = find_children($c, "data_source", min => 1, max => 1);

        my $spw = find_attr_child($dsrc, "spw_ref", "ref");
        my $ds_range = find_range($dsrc);

        $cubes{$id} = JAC::OCS::Config::ACSIS::Cube->new(
            (defined $coords ? (group_centre => $coords) : ()),
            pixsize => [$x_pix_size, $y_pix_size],
            offset => [$x_offset, $y_offset],
            npix => [$x_npix, $y_npix],
            projection => $projection,
            grid_function => $grid_function,
            tcs_coord => $tcs_coord,
            fwhm => $fwhm,
            truncation_radius => $trun_rad,
            spw_id => $spw,
            spw_interval => $ds_range,
            posang => $pa,
        );
    }

    # store the cubes
    $self->cubes(%cubes);
}

=back

=end __PRIVATE_METHODS__

=head1 XML SPECIFICATION

The ACSIS XML configuration specification is documented in
OCS/ICD/005 with a DTD available at
http://docs.jach.hawaii.edu/JCMT/OCS/ICD/005/acsis.dtd.

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
