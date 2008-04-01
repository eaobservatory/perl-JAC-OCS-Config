package JAC::OCS::Config::Instrument::SCUBA2Extras;

=head1 NAME

JAC::OCS::Config::ACSIS - Parse and modify OCS ACSIS process layout configurations

=head1 SYNOPSIS

  use JAC::OCS::Config::Instrument::SCUBA2Extras;

  $cfg = new JAC::OCS::Config::Instrument::SCUBA2Extras( DOM => $dom);

=head1 DESCRIPTION

This class can be used to parse and modify the SCUBA2 extra information
found in the instrument initialize XML.

=cut

use 5.006;
use strict;
use Carp;
use warnings;
use XML::LibXML;

use JAC::OCS::Config::Error qw| :try |;

use base qw/ JAC::OCS::Config::CfgBase /;

use vars qw/ $VERSION /;

$VERSION = sprintf("%d", q$Revision: 14392 $ =~ /(\d+)/);

=head1 METHODS

=head2 Class Methods

=over 4

=item B<getRootElementName>

Return the name of the _CONFIG element that should be the root
node of the XML tree corresponding to the ACSIS process layout config.

 @names = $h->getRootElementName;

=cut

sub getRootElementName {
  return( "SCUBA2_EXTRA" );
}

=back

=head1 XML SPECIFICATION

The SCUBA2-specific XML configuration specification is documented in
SC2/SOF/IC200/001 by Dennis Kelly.

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

Copyright (C) 2008 Science and Technology Facilities Council.
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
