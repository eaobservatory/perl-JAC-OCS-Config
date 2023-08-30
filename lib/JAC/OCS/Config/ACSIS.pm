package JAC::OCS::Config::ACSIS;

=head1 NAME

JAC::OCS::Config::ACSIS - Parse and modify OCS ACSIS configurations

=head1 SYNOPSIS

    use JAC::OCS::Config::ACSIS;

    $cfg = new JAC::OCS::Config::ACSIS(File => 'acsis.ent');

=head1 DESCRIPTION

This class can be used to parse and modify the ACSIS configuration
information present in the ACSIS_CONFIG element of an OCS configuration.

=cut

use 5.006;
use strict;
use Carp;
use warnings;
use XML::LibXML;

use JAC::OCS::Config::Error qw/:try/;

use JAC::OCS::Config::Helper qw/check_class_fatal/;
use JAC::OCS::Config::XMLHelper
    qw/find_children find_attr indent_xml_string get_pcdata/;

use JAC::OCS::Config::ACSIS::ACSIS_CORR;
use JAC::OCS::Config::ACSIS::ACSIS_IF;
use JAC::OCS::Config::ACSIS::ACSIS_MAP;

use JAC::OCS::Config::ACSIS::LineList;
use JAC::OCS::Config::ACSIS::SPWList;
use JAC::OCS::Config::ACSIS::CubeList;
use JAC::OCS::Config::ACSIS::InterfaceList;
use JAC::OCS::Config::ACSIS::RedConfigList;

use JAC::OCS::Config::ACSIS::GridderConfig;
use JAC::OCS::Config::ACSIS::SWriterConfig;
use JAC::OCS::Config::ACSIS::RTDConfig;

use JAC::OCS::Config::ACSIS::ProcessLayout;
use JAC::OCS::Config::ACSIS::ProcessLinks;
use JAC::OCS::Config::ACSIS::SemanticLinks;
use JAC::OCS::Config::ACSIS::Simulation;

use base qw/JAC::OCS::Config::CfgBase/;

our $VERSION = "1.01";

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new ACSIS configuration object. An object can be created from
a file name on disk, a chunk of XML in a string or a previously created
DOM tree generated by C<XML::LibXML> (i.e. A C<XML::LibXML::Element>).

    $cfg = new JAC::OCS::Config::ACSIS(File => $file);
    $cfg = new JAC::OCS::Config::ACSIS(XML => $xml);
    $cfg = new JAC::OCS::Config::ACSIS(DOM => $dom);

The method will die if no arguments are supplied.

=cut

sub new {
    my $self = shift;

    # Now call base class with all the supplied options +
    # extra initialiser
    return $self->SUPER::new(
        @_,
        $JAC::OCS::Config::CfgBase::INITKEY => {},
    );
}

=back

=head2 Accessor Methods

=over 4

=item B<requires_full_config>

Returns the name of any tasks that require access to the full OCS configuration
even if not all tasks are required by the subsystem.

    @tasks = $cfg->requires_full_config();

Returns "CONTROLLER".

=cut

sub requires_full_config {
    my $self = shift;

    # CONTROLLER always requires full configuration
    return ("CONTROLLER");
}

=item B<tasks>

OCS tasks that will be involved in the observation.

    @tasks = $cfg->tasks;

The number of CORRTASKs depends on the receptors that are being used.

=cut

sub tasks {
    my $self = shift;

    # get the Corr tasks
    my $map = $self->acsis_map;
    my @corrtasks;
    if (defined $map) {
        @corrtasks = $map->tasks;
    }

    return ('CONTROLLER', @corrtasks, 'IFTASK');
}

=item B<be_deg_factor>

(Optional) Backend degradation factor.

Defaults to 1.23 (ACSIS specific number).

=cut

sub be_deg_factor {
    my $self = shift;
    if (@_) {
        $self->{BE_DEG_FACTOR} = shift;
    }
    return (defined $self->{BE_DEG_FACTOR} ? $self->{BE_DEG_FACTOR} : 1.23);
}

=item B<red_obs_mode>

(Optional) String specifying the observing mode.

=cut

sub red_obs_mode {
    my $self = shift;
    if (@_) {
        $self->{RED_OBS_MODE} = shift;
    }
    return $self->{RED_OBS_MODE};
}

=item B<red_recipe_id>

(Optional) String that could be used as an ID for the dr recipe.

=cut

sub red_recipe_id {
    my $self = shift;
    if (@_) {
        $self->{RED_RECIPE_ID} = shift;
    }
    return $self->{RED_RECIPE_ID};
}

=item B<line_list>

JAC::OCS::Config::ACSIS::LineList object associated with this
configuration.

=cut

sub line_list {
    my $self = shift;
    if (@_) {
        $self->{LINE_LIST} = check_class_fatal(
            "JAC::OCS::Config::ACSIS::LineList", shift);
    }
    return $self->{LINE_LIST};
}

=item B<cube_list>

JAC::OCS::Config::ACSIS::CubeList object associated with this
configuration.

=cut

sub cube_list {
    my $self = shift;
    if (@_) {
        $self->{CUBE_LIST} = check_class_fatal(
            "JAC::OCS::Config::ACSIS::CubeList", shift);
    }
    return $self->{CUBE_LIST};
}

=item B<spw_list>

JAC::OCS::Config::ACSIS::SPWList object associated with this
configuration.

=cut

sub spw_list {
    my $self = shift;
    if (@_) {
        $self->{SPW_LIST} = check_class_fatal(
            "JAC::OCS::Config::ACSIS::SPWList", shift);
    }
    return $self->{SPW_LIST};
}

=item B<acsis_if>

JAC::OCS::Config::ACSIS::ACSIS_IF object associated with this
configuration.

=cut

sub acsis_if {
    my $self = shift;
    if (@_) {
        $self->{ACSIS_IF} = check_class_fatal(
            "JAC::OCS::Config::ACSIS::ACSIS_IF", shift);
    }
    return $self->{ACSIS_IF};
}

=item B<acsis_corr>

JAC::OCS::Config::ACSIS::ACSIS_CORR object associated with this
configuration.

=cut

sub acsis_corr {
    my $self = shift;
    if (@_) {
        $self->{ACSIS_CORR} = check_class_fatal(
            "JAC::OCS::Config::ACSIS::ACSIS_CORR", shift);
    }
    return $self->{ACSIS_CORR};
}

=item B<acsis_map>

JAC::OCS::Config::ACSIS::ACSIS_MAP object associated with this
configuration.

=cut

sub acsis_map {
    my $self = shift;
    if (@_) {
        $self->{ACSIS_MAP} = check_class_fatal(
            "JAC::OCS::Config::ACSIS::ACSIS_MAP", shift);
    }
    return $self->{ACSIS_MAP};
}

=item B<semantic_links>

JAC::OCS::Config::ACSIS::SemanticLinks object associated with this
configuration.

=cut

sub semantic_links {
    my $self = shift;
    if (@_) {
        $self->{SEMANTIC_LINKS} = check_class_fatal(
            "JAC::OCS::Config::ACSIS::SemanticLinks", shift);
    }
    return $self->{SEMANTIC_LINKS};
}

=item B<red_config_list>

JAC::OCS::Config::ACSIS::RedConfigList object associated with this
configuration.

=cut

sub red_config_list {
    my $self = shift;
    if (@_) {
        $self->{RED_CONFIG_LIST} = check_class_fatal(
            "JAC::OCS::Config::ACSIS::RedConfigList", shift);
    }
    return $self->{RED_CONFIG_LIST};
}

=item B<gridder_config>

JAC::OCS::Config::ACSIS::GridderConfig object associated with this
configuration.

=cut

sub gridder_config {
    my $self = shift;
    if (@_) {
        $self->{GRIDDER_CONFIG} = check_class_fatal(
            "JAC::OCS::Config::ACSIS::GridderConfig", shift);
    }
    return $self->{GRIDDER_CONFIG};
}

=item B<swriter_config>

JAC::OCS::Config::ACSIS::SWriterConfig object associated with this
configuration.

=cut

sub swriter_config {
    my $self = shift;
    if (@_) {
        $self->{SWRITER_CONFIG} = check_class_fatal(
            "JAC::OCS::Config::ACSIS::SWriterConfig", shift);
    }
    return $self->{SWRITER_CONFIG};
}

=item B<rtd_config>

JAC::OCS::Config::ACSIS::RTDConfig object associated with this
configuration.

=cut

sub rtd_config {
    my $self = shift;
    if (@_) {
        $self->{RTD_CONFIG} = check_class_fatal(
            "JAC::OCS::Config::ACSIS::RTDConfig", shift);
    }
    return $self->{RTD_CONFIG};
}

=item B<process_layout>

JAC::OCS::Config::ACSIS::ProcessLayout object associated with this
configuration.

=cut

sub process_layout {
    my $self = shift;
    if (@_) {
        $self->{PROCESS_LAYOUT} = check_class_fatal(
            "JAC::OCS::Config::ACSIS::ProcessLayout", shift);
    }
    return $self->{PROCESS_LAYOUT};
}

=item B<process_links>

JAC::OCS::Config::ACSIS::ProcessLinks object associated with this
configuration.

=cut

sub process_links {
    my $self = shift;
    if (@_) {
        $self->{PROCESS_LINKS} = check_class_fatal(
            "JAC::OCS::Config::ACSIS::ProcessLinks", shift);
    }
    return $self->{PROCESS_LINKS};
}

=item B<interface_list>

JAC::OCS::Config::ACSIS::InterfaceList object associated with this
configuration.

=cut

sub interface_list {
    my $self = shift;
    if (@_) {
        $self->{INTERFACE_LIST} = check_class_fatal(
            "JAC::OCS::Config::ACSIS::InterfaceList", shift);
    }
    return $self->{INTERFACE_LIST};
}

=item B<simulation>

JAC::OCS::Config::ACSIS::Simulation object associated with this
configuration.

=cut

sub simulation {
    my $self = shift;
    if (@_) {
        $self->{SIMULATION} = check_class_fatal(
            "JAC::OCS::Config::ACSIS::Simulation", shift);
    }
    return $self->{SIMULATION};
}


=item B<stringify>

Create XML representation of object.

=cut

sub stringify {
    my $self = shift;
    my %args = @_;

    my $xml = "<ACSIS_CONFIG>\n";

    # Version declaration
    $xml .= $self->_introductory_xml();

    $xml .= $self->cube_list->stringify(NOINDENT => 0) . "\n"
        if defined $self->cube_list;
    $xml .= $self->line_list->stringify(NOINDENT => 0) . "\n"
        if defined $self->line_list;
    $xml .= $self->spw_list->stringify(NOINDENT => 0) . "\n"
        if defined $self->spw_list;
    $xml .= $self->acsis_if->stringify(NOINDENT => 0) . "\n"
        if defined $self->acsis_if;
    $xml .= $self->acsis_corr->stringify(NOINDENT => 0) . "\n"
        if defined $self->acsis_corr;
    $xml .= $self->acsis_map->stringify(NOINDENT => 0) . "\n"
        if defined $self->acsis_map;

    $xml .= "<be_deg_factor>" . $self->be_deg_factor . "</be_deg_factor>\n";

    $xml .= "<red_obs_mode>" . $self->red_obs_mode . "</red_obs_mode>\n"
        if defined $self->red_obs_mode;

    $xml .= "<red_recipe_id>" . $self->red_recipe_id . "</red_recipe_id>\n"
        if defined $self->red_recipe_id;

    $xml .= $self->semantic_links->stringify(NOINDENT => 0) . "\n"
        if defined $self->semantic_links;
    $xml .= $self->red_config_list->stringify(NOINDENT => 0) . "\n"
        if defined $self->red_config_list;
    $xml .= $self->gridder_config->stringify(NOINDENT => 0) . "\n"
        if defined $self->gridder_config;
    $xml .= $self->swriter_config->stringify(NOINDENT => 0) . "\n"
        if defined $self->swriter_config;
    $xml .= $self->rtd_config->stringify(NOINDENT => 0) . "\n"
        if defined $self->rtd_config;
    $xml .= $self->process_layout->stringify(NOINDENT => 0) . "\n"
        if defined $self->process_layout;
    $xml .= $self->process_links->stringify(NOINDENT => 0) . "\n"
        if defined $self->process_links;
    $xml .= $self->interface_list->stringify(NOINDENT => 0) . "\n"
        if defined $self->interface_list;

    # optional
    $xml .= $self->simulation->stringify(NOINDENT => 0) . "\n"
        if defined $self->simulation;

    $xml .= "\n</ACSIS_CONFIG>\n";

    return ($args{NOINDENT} ? $xml : indent_xml_string($xml));
}

=back

=head2 Class Methods

=over 4

=item B<dtdrequires>

Returns the names of any associated configurations required for this
configuration to be used in a full OCS_CONFIG. ACSIS requires
'instrument_setup', 'header', 'obs_summary' and 'frontend'.

    @requires = $cfg->dtdrequires();

=cut

sub dtdrequires {
    return ('instrument_setup', 'header', 'frontend', 'obs_summary');
}

=item B<getRootElementName>

Return the name of the _CONFIG element that should be the root
node of the XML tree corresponding to the ACSIS config.

    @names = $h->getRootElementName;

=cut

sub getRootElementName {
    return ("ACSIS_CONFIG");
}

=back

=begin __PRIVATE_METHODS__

=head2 Private Methods

=over 4

=item B<_process_dom>

Using the C<_rootnode> node referring to the top of the ACSIS XML,
process the DOM tree and extract all the coordinate information.

    $self->_process_dom;

Populates the object with the extracted results.

=cut

sub _process_dom {
    my $self = shift;

    # Find all the header items
    my $el = $self->_rootnode;

    # Deal with each sub-element independently
    # A * indicates optional. Most things are mandatory.

    # line_list
    my $o = new JAC::OCS::Config::ACSIS::LineList(DOM => $el);
    $self->line_list($o);

    # cube_list
    $o = new JAC::OCS::Config::ACSIS::CubeList(DOM => $el);
    $self->cube_list($o);

    # spw_list
    $o = new JAC::OCS::Config::ACSIS::SPWList(DOM => $el);
    $self->spw_list($o);

    # ACSIS_IF
    $o = new JAC::OCS::Config::ACSIS::ACSIS_IF(DOM => $el);
    $self->acsis_if($o);

    # ACSIS_corr
    $o = new JAC::OCS::Config::ACSIS::ACSIS_CORR(DOM => $el);
    $self->acsis_corr($o);

    # ACSIS_map
    $o = new JAC::OCS::Config::ACSIS::ACSIS_MAP(DOM => $el);
    $self->acsis_map($o);

    # red_obs_mode  *
    my $mode = get_pcdata($el, "red_obs_mode");
    $self->red_obs_mode($mode) if defined $mode;

    # red_recipe_id *
    my $id = get_pcdata($el, "red_recipe_id");
    $self->red_recipe_id($mode) if defined $id;

    # semantic_links
    $o = new JAC::OCS::Config::ACSIS::SemanticLinks(DOM => $el);
    $self->semantic_links($o);

    # red_config_list
    $o = new JAC::OCS::Config::ACSIS::RedConfigList(DOM => $el);
    $self->red_config_list($o);

    # gridder_config
    $o = new JAC::OCS::Config::ACSIS::GridderConfig(DOM => $el);
    $self->gridder_config($o);

    # swriter_config [optional]
    try {
        $o = new JAC::OCS::Config::ACSIS::SWriterConfig(DOM => $el);
        $self->swriter_config($o);
    }
    catch JAC::OCS::Config::Error::XMLConfigMissing with {
        # can be ignored
    };

    # rtd_config
    $o = new JAC::OCS::Config::ACSIS::RTDConfig(DOM => $el);
    $self->rtd_config($o);

    # process_layout
    $o = new JAC::OCS::Config::ACSIS::ProcessLayout(DOM => $el);
    $self->process_layout($o);

    # process_links [optional]
    try {
        $o = new JAC::OCS::Config::ACSIS::ProcessLinks(DOM => $el);
        $self->process_links($o);
    }
    catch JAC::OCS::Config::Error::XMLConfigMissing with {
        # can be ignored
    };

    # interface_list
    $o = new JAC::OCS::Config::ACSIS::InterfaceList(DOM => $el);
    $self->interface_list($o);

    # simulation * optional
    try {
        $o = new JAC::OCS::Config::ACSIS::Simulation(DOM => $el);
        $self->simulation($o);
    }
    catch JAC::OCS::Config::Error::XMLConfigMissing with {
        # this error is okay
    };

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
