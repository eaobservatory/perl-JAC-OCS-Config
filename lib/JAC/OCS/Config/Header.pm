package JAC::OCS::Config::Header;

=head1 NAME

JAC::OCS::Config::Header - Parse and modify OCS HEADER configurations

=head1 SYNOPSIS

  use JAC::OCS::Config::Header;

  $cfg = new JAC::OCS::Config::Header( File => 'header.ent');

=head1 DESCRIPTION

This class can be used to parse and modify the header configuration
information present in the HEADER_CONFIG element of an OCS configuration.


=cut

use 5.006;
use strict;
use Carp;
use warnings;
use XML::LibXML;

use JAC::OCS::Config::Error qw| :try |;

use base qw/ JAC::OCS::Config::CfgBase /;

use vars qw/ $VERSION /;

$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

=cut

sub new {

}

=back

=head1 XML SPECIFICATION

The TCS XML configuration specification is documented in OCS/ICD/006
with a DTD available at
L<http://www.jach.hawaii.edu/JACdocs/JCMT/OCS/ICD/006/tcs.dtd>. A
schema is also available as part of the TOML definition used by the
JAC Observing Tool, but note that the XML dialects differ in their uses
even though they use the same low-level representation of an astronomical
target.

=head1 HISTORY

This code was originally part of the C<OMP::MSB> class and was then
extracted into a separate C<TOML::TCS> module. During work on the new
ACSIS translator it was felt that a Config namespace was more correct
and so the C<TOML> namespace was deprecated.

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

Copyright 2002-2004 Particle Physics and Astronomy Research Council.
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
