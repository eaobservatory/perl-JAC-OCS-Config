package JAC::OCS::Config::ACSIS::GridderConfig;

=head1 NAME

JAC::OCS::Config::ACSIS::GridderConfig - Parse and modify OCS ACSIS gridder configurations

=head1 SYNOPSIS

    use JAC::OCS::Config::ACSIS::GridderConfig;

    $cfg = new JAC::OCS::Config::ACSIS::GridderConfig(DOM => $dom);

=head1 DESCRIPTION

This class can be used to parse and modify the ACSIS gridder configuration
information present in the C<gridder_config> element of an OCS configuration.

=cut

use 5.006;
use strict;
use Carp;
use warnings;
use XML::LibXML;

use JAC::OCS::Config::Error qw/:try/;

use base qw/JAC::OCS::Config::CfgBase/;

our $VERSION = "1.01";

=head1 METHODS

=head2 Class Methods

=over 4

=item B<getRootElementName>

Return the name of the _CONFIG element that should be the root
node of the XML tree corresponding to the ACSIS gridder config.

    @names = $h->getRootElementName;

=cut

sub getRootElementName {
    return ("gridder_config");
}

=back

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
