package JAC::OCS::Config::ACSIS::InterfaceList;

=head1 NAME

JAC::OCS::Config::ACSIS - Parse and modify OCS ACSIS interface configurations

=head1 SYNOPSIS

  use JAC::OCS::Config::ACSIS::InterfaceList;

  $cfg = new JAC::OCS::Config::ACSIS::InterfaceList( DOM => $dom);

=head1 DESCRIPTION

This class can be used to parse and modify the ACSIS interface configuration
information present in the C<interface_list> element of an OCS configuration.

=cut

use 5.006;
use strict;
use Carp;
use warnings;
use XML::LibXML;

use JAC::OCS::Config::Error qw| :try |;

use JAC::OCS::Config::XMLHelper qw(
				   find_children
				   find_attr
				  );

use base qw/ JAC::OCS::Config::CfgBase /;

use vars qw/ $VERSION /;

$VERSION = sprintf("%d", q$Revision$ =~ /(\d+)/);

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new InterfaceList configuration object. An object can be created from
a file name on disk, a chunk of XML in a string or a previously created
DOM tree generated by C<XML::LibXML> (i.e. A C<XML::LibXML::Element>).

  $cfg = new JAC::OCS::Config::ACSIS::InterfaceList( File => $file );
  $cfg = new JAC::OCS::Config::ACSIS::InterfaceList( XML => $xml );
  $cfg = new JAC::OCS::Config::ACSIS::InterfaceList( DOM => $dom );

A blank object will be created if no arguments are supplied.

=cut

sub new {
  my $self = shift;

  # Now call base class with all the supplied options +
  # extra initialiser
  return $self->SUPER::new( @_, 
			    $JAC::OCS::Config::CfgBase::INITKEY => { 
				                                    eventNames => {},
								   }
			  );
}

=back

=head2 Accessor Methods

=over 4

=item B<getEventNames>

Return the names of the outgoing data events matching the given 
interface name.

  @eventNames = $il->getEventName("RTS_MONITOR_INTERFACE");

=cut

sub getEventNames {
  my $self = shift;
  my $interfaceName = shift;
  return @{$self->{eventNames}}{$interfaceName};
}

=back

=head2 Class Methods

=over 4

=item B<getRootElementName>

Return the name of the _CONFIG element that should be the root
node of the XML tree corresponding to the ACSIS interface config.

 @names = $h->getRootElementName;

=cut

sub getRootElementName {
  return( "interface_list" );
}

=back

=begin __PRIVATE_METHODS__

=head2 Private Methods

=over 4

=item B<_process_dom>

Using the C<_rootnode> node referring to the top of the Instrument XML,
process the DOM tree and extract the names of the monitors. Note that
it does not process all the information in the xml tree, because we
only need to expose the names of data events. Because stringify is not
implemented here, CfgBase will return the xml that was given to the
constructor.

 $self->_process_dom;

Extracts the monitorIds and stores them for later retrieval.

=cut

sub _process_dom {
  my $self = shift;

  my $el = $self->_rootnode;
  my @interfaces = find_children( $el, "interface", min => 1);
  for my $interface (@interfaces) {
    my $interfaceId = find_attr( $interface, "id");
    my $outevents = find_children( $interface, "out_events", min => 1, max => 1);
    my @events = find_children( $outevents, "event");
    my @eventNames;
    for my $event (@events) {
      my $name = find_attr( $event, "id");
      push @eventNames, $name;
    }
    ${$self->{eventNames}}{$interfaceId} = \@eventNames;
  }
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
