package JAC::OCS::Config::ACSIS::ACSIS_IF;

=head1 NAME

JAC::OCS::Config::ACSIS_IF - Parse and modify OCS ACSIS IF configurations

=head1 SYNOPSIS

    use JAC::OCS::Config::ACSIS::ACSIS_IF;

    $cfg = new JAC::OCS::Config::ACSIS::ACSIS_IF(DOM => $dom);

=head1 DESCRIPTION

This class can be used to parse and modify the ACSIS IF configuration
information present in the C<ACSIS_IF> element of an OCS configuration.

=cut

use 5.006;
use strict;
use Carp;
use warnings;
use warnings::register;
use XML::LibXML;

use JAC::OCS::Config::Error qw/:try/;

use JAC::OCS::Config::XMLHelper qw/
    find_children find_attr find_attr_child indent_xml_string/;

use base qw/JAC::OCS::Config::CfgBase/;

our $VERSION = "1.01";

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new ACSIS correlator configuration object. An object can be
created from a file name on disk, a chunk of XML in a string or a
previously created DOM tree generated by C<XML::LibXML> (i.e. A
C<XML::LibXML::Element>).

    $cfg = new JAC::OCS::Config::ACSIS_CORR(File => $file);
    $cfg = new JAC::OCS::Config::ACSIS_CORR(XML => $xml);
    $cfg = new JAC::OCS::Config::ACSIS_CORR(DOM => $dom);

A blank mapping can be created.

=cut

sub new {
    my $self = shift;

    # Now call base class with all the supplied options +
    # extra initialiser
    return $self->SUPER::new(
        @_,
        $JAC::OCS::Config::CfgBase::INITKEY => {
            BWMODES => [],
            LO2FREQS => [],
            SBMODES => [],
        }
    );
}

=back

=head2 Accessor Methods

=over 4

=item B<bw_modes>

The bandwidth modes, indexed by DCM ID. Note that not all 32 elements will
necessarily have to be defined.

    @modes = $if->bw_modes();
    $if->bw_modes(@modes);

=cut

sub bw_modes {
    my $self = shift;
    if (@_) {
        my @modes = @_;
        warnings::warnif("More than 32 band width modes specified!")
            if $#modes > 31;
        @{$self->{BWMODES}} = @modes;
    }
    return @{$self->{BWMODES}};
}

=item B<bw_modes>

The subband modes, indexed by quadrant ID. Note that not all 4 elements will
necessarily have to be defined.

    @modes = $if->sb_modes();
    $if->sb_modes(@modes);

=cut

sub sb_modes {
    my $self = shift;
    if (@_) {
        my @modes = @_;
        warnings::warnif("More than 4 subband modes specified!")
            if $#modes > 3;
        @{$self->{SBMODES}} = @modes;
    }
    return @{$self->{SBMODES}};
}

=item B<lo2freqs>

The frequency settings for each LO2 (up to 4).

    @freqs = $if->lo2freqs();
    $if->lo2freqs(@freqs);

The array is zero-indexed (so has a max index of 3) even though the LO2s
are counted from 1. On stringification any missing/uneeded LO2 settings
will be filled in from the first valie value.

Units are in Hz

=cut

sub lo2freqs {
    my $self = shift;
    if (@_) {
        my @freqs = @_;
        warnings::warnif("More than 4 LO2 frequencies specified!")
            if $#freqs > 3;
        @{$self->{LO2FREQS}} = @freqs;
    }
    return @{$self->{LO2FREQS}};
}

=item B<lo3freq>

The frequency setting for LO3.

    $freq = $if->lo3freq();
    $if->lo3fre($freq);

=cut

sub lo3freq {
    my $self = shift;
    if (@_) {
        $self->{LO3FREQ} = shift;
    }
    return $self->{LO3FREQ};
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

    # loop over the cm_map
    my @modes = $self->bw_modes;

    # FOR ACSIS WE ALWAYS NEED TO DEFINE 32 !!!
    # define them all to the first value
    my $dummy;
    for my $dcm_id (0 .. $#modes) {
        if (defined $modes[$dcm_id]) {
            $dummy = $modes[$dcm_id];
            last;
        }
    }
    throw JAC::OCS::Config::Error::FatalError(
        "No Correlator mode defined. Can not write XML\n")
        unless defined $dummy;

    for my $dcm_id (0 .. 31) {
        my $mode = (defined $modes[$dcm_id] ? $modes[$dcm_id] : $dummy);
        $xml .= '<dcm id="' . $dcm_id . '" bw_mode="' . $mode . "\"/>\n";
    }

    # We must have a reference LO2 to fill in missing values
    # If possible LO1 = LO3 and LO2 = LO4
    my @lo = $self->lo2freqs();

    my $filler = 0.0;
    for (@lo) {
        if (defined $_) {
            $filler = $_;
            last;
        }
    }
    warnings::warnif("No LO2 specified at all. Using 0.0")
        if $filler == 0;

    # Fill in gaps. We should preferentially use the LO two steps
    # away
    for my $id (0 .. 3) {
        if (!defined $lo[$id]) {
            my $i = $id + ($id < 2 ? 2 : -2);
            $lo[$id] = (defined $lo[$i] ? $lo[$i] : $filler);
        }
    }

    # Now Loop over LO2 for real but we are forced to write out 4 LO2 settings
    for my $id (0 .. 3) {
        # this should now always return a set LO
        my $freq = $lo[$id];

        # Correct to MHz
        $freq /= 1E6;

        $xml .= '<lo2 id="' . $id . '" freq="' . $freq . "\"/>\n";
    }

    # lo3
    $xml .= '<lo3 freq="' . $self->lo3freq . "\"/>\n";

    # subband mode for each Quadrant
    # Loop over LO2
    my @sbmode = $self->sb_modes();
    for my $qid (0 .. $#sbmode) {
        next unless defined $sbmode[$qid];
        $xml .= '<quadrant id="'
            . $qid
            . '" subband_mode="'
            . $sbmode[$qid]
            . "\"/>\n";
    }

    # tidy up
    $xml .= "</" . $self->getRootElementName . ">\n";

    return ($args{NOINDENT} ? $xml : indent_xml_string($xml));
}

=back

=head2 Class Methods

=over 4

=item B<getRootElementName>

Return the name of the _CONFIG element that should be the root
node of the XML tree corresponding to the ACSIS IF config.

    @names = $h->getRootElementName;

=cut

sub getRootElementName {
    return ("ACSIS_IF");
}

=back

=begin __PRIVATE_METHODS__

=head2 Private Methods

=over 4

=item B<_process_dom>

Using the C<_rootnode> node referring to the top of the ACSIS_IF XML,
process the DOM tree and extract all the coordinate information.

    $self->_process_dom;

Populates the object with the extracted results.

=cut

sub _process_dom {
    my $self = shift;

    # Find all the header items
    my $el = $self->_rootnode;

    # First the DCM configuration
    my @dcm = find_children($el, "dcm", min => 1, max => 32);

    my @bwmodes;
    for my $dcmel (@dcm) {
        my %attr = find_attr($dcmel, "id", "bw_mode");
        $bwmodes[$attr{id}] = $attr{bw_mode};
    }

    $self->bw_modes(@bwmodes);

    # LO2 settings. All numbering starts at 0
    my @lo2 = find_children($el, "lo2", min => 1, max => 4);
    my @lo2freq;
    for my $loel (@lo2) {
        my %attr = find_attr($loel, "id", "freq");
        # MHz to Hz internally
        $lo2freq[$attr{id}] = $attr{freq} * 1E6;
    }
    $self->lo2freqs(@lo2freq);

    # LO3
    my $lo3 = find_attr_child($el, "lo3", "freq");
    $self->lo3freq($lo3);

    # subband modes
    my @quads = find_children($el, "quadrant", min => 1, max => 4);
    my @sbmodes;
    for my $qel (@quads) {
        my %attr = find_attr($qel, "id", "subband_mode");
        $sbmodes[$attr{id}] = $attr{subband_mode};
    }
    $self->sb_modes(@sbmodes);

    return;
}

=back

=end __PRIVATE_METHODS__

=head1 XML SPECIFICATION

The ACSIS XML configuration specification is documented in
OCS/ICD/005 with a DTD available at
http://docs.jach.hawaii.edu/JCMT/OCS/ICD/005/acsis.dtd.

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

Copyright 2004-2005 Particle Physics and Astronomy Research Council.
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
