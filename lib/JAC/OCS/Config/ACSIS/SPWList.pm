package JAC::OCS::Config::ACSIS::SPWList;

=head1 NAME

JAC::OCS::Config::ACSIS::SPWList - Parse and modify OCS ACSIS spectral window configurations

=head1 SYNOPSIS

    use JAC::OCS::Config::ACSIS::SPWList;

    $cfg = new JAC::OCS::Config::ACSIS::SPWList(DOM => $dom);

=head1 DESCRIPTION

This class can be used to parse and modify the ACSIS spectral window configuration
information present in the C<spw_list> element of an OCS configuration.

=cut

use 5.006;
use strict;
use Carp;
use warnings;
use XML::LibXML;

use JAC::OCS::Config::Error qw/:try/;
use JAC::OCS::Config::Units;

use JAC::OCS::Config::ACSIS::SpectralWindow;
use JAC::OCS::Config::ACSIS::IFCoord;

use JAC::OCS::Config::XMLHelper qw/
    find_attr_child find_attr get_pcdata find_attrs_and_pcdata find_children
    indent_xml_string find_range interval_to_xml attrs_only/;

use JAC::OCS::Config::Helper qw/check_class_hash_fatal/;

use base qw/JAC::OCS::Config::CfgBase/;

our $VERSION = "1.01";

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new SPWList configuration object. An object can be created from
a file name on disk, a chunk of XML in a string or a previously created
DOM tree generated by C<XML::LibXML> (i.e. A C<XML::LibXML::Element>).

    $cfg = new JAC::OCS::Config::ACSIS::SPWList(File => $file);
    $cfg = new JAC::OCS::Config::ACSIS::SPWList(XML => $xml);
    $cfg = new JAC::OCS::Config::ACSIS::SPWList(DOM => $dom);

The method will die if no arguments are supplied.

=cut

sub new {
    my $self = shift;

    # Now call base class with all the supplied options +
    # extra initialiser
    return $self->SUPER::new(
        @_,
        $JAC::OCS::Config::CfgBase::INITKEY => {
            SPWS => {},
            DATA_FIELDS => {},
        });
}

=back

=head2 Accessor Methods

=over 4

=item B<spectral_windows>

Array of C<JAC::OCS::Config::ACSIS::SpectralWindow> objects.

=cut

sub spectral_windows {
    my $self = shift;
    if (@_) {
        %{$self->{SPWS}} = check_class_hash_fatal("JAC::OCS::Config::ACSIS::SpectralWindow", @_);
    }
    return %{$self->{SPWS}};
}

=item B<data_fields>

Location of data fields in the incoming Glish packets.

=cut

sub data_fields {
    my $self = shift;
    if (@_) {
        %{$self->{DATA_FIELDS}} = @_;
    }
    return %{$self->{DATA_FIELDS}};
}

=item B<subbands>

Return all the non-hybridized spectral window objects. ie either the
constituent subbands (but not the hybrid) or the main spectral window
object that covers a single subband.

    %subbands = $spwl->subbands;

The keys are the spectral window IDs for each subband.

=cut

sub subbands {
    my $self = shift;

    my %subbands;

    my %spw = $self->spectral_windows;

    for my $id (keys %spw) {
        my %sb = $spw{$id}->subbands;

        if (keys %sb) {
            # we have subbands
            for my $sbid (keys %sb) {
                $subbands{$sbid} = $sb{$sbid};
            }
        }
        else {
            # this is non-hybrid
            $subbands{$id} = $spw{$id};
        }
    }

    return %subbands;
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

    # data fields (order is important)
    my %df = $self->data_fields;
    for my $k ("doppler", "spw_id", "fe_lo") {
        next unless exists $df{$k};
        $xml .= "<$k" . "_field ref=\"$df{$k}\"/>\n";
    }

    my %spw = $self->spectral_windows;

    # loop over all spectral windows (sort for predictability)
    for my $k (sort keys %spw) {
        # Create each spectral window and then immediately include
        # subband specifications
        my %subbands = $spw{$k}->subbands;

        # Now loop over each spectral window and associated subband
        for my $spwid ($k, keys %subbands) {
            # The actual spectral window object is either in %spw or %subbands
            my $sw = (exists $spw{$spwid} ? $spw{$spwid} : $subbands{$spwid});

            my $specid = $sw->spectrum_id();

            $xml .= "<spectral_window id=\"$spwid\""
                . ((defined $specid) ? " spectrum_id=\"$specid\"" : '') . ">\n";

            if ($sw->subbands) {
                $xml .= "<subband_list>\n";
                my %sb = $sw->subbands;
                $xml .= join("\n", map {"<subband ref=\"$_\"/>"} keys %sb) . "\n";
                $xml .= "</subband_list>\n";
            }
            else {
                # mode, window and align
                $xml .= attrs_only("bandwidth_mode", mode => $sw->bandwidth_mode);
                $xml .= attrs_only("window", type => $sw->window);

                # shift in channels
                my $shift = $sw->align_shift;

                $xml .= "<align_shift>" . $shift . "</align_shift>\n";
            }

            $xml .= attrs_only("rest_freq_ref", ref => $sw->rest_freq_ref);
            $xml .= attrs_only("fe_sideband", sideband => $sw->fe_sideband);

            # IF Coordinate
            my $ifcrd = $sw->if_coordinate;
            $xml .= "<if_coordinate>\n";

            # Gridder is stupid and will not read the units so wants GHz
            $xml .= "<if_ref_freq units=\"GHz\">"
                . ($ifcrd->if_freq / 1.0E9)
                . "</if_ref_freq>\n";
            $xml .= "<if_ref_channel>"
                . $ifcrd->ref_channel
                . "</if_ref_channel>\n";
            $xml .= "<if_chan_width units=\"Hz\">"
                . $ifcrd->channel_width
                . "</if_chan_width>\n";
            $xml .= "<if_nchans>" . $ifcrd->nchannels . "</if_nchans>\n";
            $xml .= "</if_coordinate>\n";

            my @blregion = $sw->baseline_region();
            if (@blregion) {
                my %params = $sw->baseline_fit;
                $xml .= "<baseline_fit>\n";
                if ($params{function} eq 'polynomial') {
                    $xml .= attrs_only("fit_polynomial",
                        "degree" => $params{degree});
                }

                $xml .= "<fit_region>\n";
                $xml .= interval_to_xml(@blregion);
                $xml .= "</fit_region>\n";
                $xml .= "</baseline_fit>\n";
            }

            my @lregion = $sw->line_region;
            if (@lregion) {
                $xml .= "<line_region>\n";
                $xml .= interval_to_xml(@lregion);
                $xml .= "</line_region>\n";
            }

            $xml .= "</spectral_window>\n";
        }
    }

    $xml .= "</" . $self->getRootElementName . ">\n";

    return ($args{NOINDENT} ? $xml : indent_xml_string($xml));
}

=back

=head2 Class Methods

=over 4

=item B<getRootElementName>

Return the name of the _CONFIG element that should be the root
node of the XML tree corresponding to the ACSIS spectral window config.

    @names = $h->getRootElementName;

=cut

sub getRootElementName {
    return ("spw_list");
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

    # First thing we have to do is to get the look up tables
    # which specify where specific information can be found in the
    # incoming data structures
    my %data_fields;
    $data_fields{doppler} = find_attr_child($el, "doppler_field", "ref");
    $data_fields{spw_id} = find_attr_child($el, "spw_id_field", "ref");
    $data_fields{fe_lo} = find_attr_child($el, "fe_lo_field", "ref");

    $self->data_fields(%data_fields);

    # need to get all the spectral window elements
    my @spwxml = find_children($el, "spectral_window", min => 1);

    # somewhere to store the spectral window objects
    my %spw;

    # subband lookup table
    my %subbands;

    # Now extract information from each spectral window
    for my $spw (@spwxml) {
        my $id = find_attr($spw, "id");
        my $specid = find_attr($spw, 'spectrum_id');

        # print "======================== ID $id ====================================\n";

        # Either have Subband list *OR*
        #  bandwidth mode + window + align_shift
        # subband list has zero or more subband elements
        # The subbands refer to OTHER spectral windows

        # first look for subband_list
        my $slist = find_children($spw, "subband_list", min => 0, max => 1);

        my ($bwmode, $wintype, $align_shift);
        if ($slist) {
            # now find the subbands
            my @children = find_children($slist, "subband", min => 0);
            my @refs = map {scalar find_attr($_, "ref")} @children;
            $subbands{$id} = \@refs;
        }
        else {
            # bandwidth mode etc for specific subband
            $bwmode = find_attr_child($spw, "bandwidth_mode", "mode");
            $wintype = find_attr_child($spw, "window", "type");

            # channels
            $align_shift = get_pcdata($spw, "align_shift");
        }

        # Reference to rest frequency (see line_list)
        my $rest_freq = find_attr_child($spw, "rest_freq_ref", "ref");

        # Sideband information (must correspond to frontend config)
        my $sideband = find_attr_child($spw, "fe_sideband", "sideband");

        # IF coordinates (mandatory)
        my $ifcoord = find_children($spw, "if_coordinate", min => 1, max => 1);

        my $ifcrd;
        if ($ifcoord) {
            #  IF frequency
            my ($if, %attr) = find_attrs_and_pcdata($ifcoord, "if_ref_freq");
            $if = JAC::OCS::Config::Units->to_base($if, $attr{units});

            #  IF Reference channel
            my $ref_channel = get_pcdata($ifcoord, "if_ref_channel");

            #  Channel spacing
            (my $chan_wid, %attr) = find_attrs_and_pcdata($ifcoord, "if_chan_width");
            $chan_wid = JAC::OCS::Config::Units->to_base($chan_wid, $attr{units});

            #  Number of channels
            my $nchans = get_pcdata($ifcoord, "if_nchans");

            # create the object
            $ifcrd = JAC::OCS::Config::ACSIS::IFCoord->new(
                if_freq => $if,
                ref_channel => $ref_channel,
                channel_width => $chan_wid,
                nchannels => $nchans,
            );
        }

        # Baseline fitting [optional]
        my $bfit = find_children($spw, "baseline_fit", min => 0, max => 1);

        my (@blregions, $order_poly);
        if ($bfit) {
            # Order of polynomial (optional)
            $order_poly = find_attr_child($bfit, "fit_polynomial", "degree");

            # Fit region contains multiple ranges
            my $fr = find_children($bfit, "fit_region", min => 1, max => 1);
            @blregions = find_range($fr);
        }

        # line region of interest
        # is a range/interval. Optional
        my $lregion = find_children($spw, "line_region", min => 0, max => 1);
        my @lregions;
        @lregions = find_range($lregion) if $lregion;

        # Create spectral window object
        $spw{$id} = JAC::OCS::Config::ACSIS::SpectralWindow->new(
            spectrum_id => $specid,
            fe_sideband => $sideband,
            rest_freq_ref => $rest_freq,
            if_coordinate => $ifcrd,
        );

        if (!exists $subbands{$id}) {
            # This is a subband
            $spw{$id}->bandwidth_mode($bwmode);
            $spw{$id}->window($wintype);
            $spw{$id}->align_shift($align_shift);
        }

        # Add fitting information if present
        $spw{$id}->baseline_region(@blregions) if @blregions;
        $spw{$id}->baseline_fit(
            function => 'polynomial',
            degree => $order_poly,
        ) if defined $order_poly;
        $spw{$id}->line_region(@lregions) if @lregions;
    }

    # Attach sub-windows to parent window and delete from primary
    for my $spwid (keys %subbands) {
        # Get all the subband ids
        my %sub;
        for my $sb (@{$subbands{$spwid}}) {
            $sub{$sb} = $spw{$sb};
            delete $spw{$sb};
        }
        $spw{$spwid}->subbands(%sub);
    }

    # And store it
    $self->spectral_windows(%spw);
}

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
