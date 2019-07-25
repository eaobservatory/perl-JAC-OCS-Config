package JAC::OCS::Config::ACSIS::ProcessLinks;

=head1 NAME

JAC::OCS::Config::ACSIS::ProcessLinks - Parse and modify OCS ACSIS process link configurations

=head1 SYNOPSIS

  use JAC::OCS::Config::ACSIS::ProcessLinks;

  $cfg = new JAC::OCS::Config::ACSIS::ProcessLinks( DOM => $dom);

=head1 DESCRIPTION

This class can be used to parse and modify the ACSIS process link configuration
information present in the C<process_links> element of an OCS configuration.

=cut

use 5.006;
use strict;
use Carp;
use warnings;
use XML::LibXML;

use JAC::OCS::Config::Error qw| :try |;
use JAC::OCS::Config::ACSIS::ProcessLink;

use JAC::OCS::Config::XMLHelper qw(
				   find_children
				   find_attr
				   indent_xml_string
				  );

use base qw/ JAC::OCS::Config::CfgBase /;

use vars qw/ $VERSION /;

$VERSION = "1.01";

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new ProcessLinks configuration object. An object can be created from
a file name on disk, a chunk of XML in a string or a previously created
DOM tree generated by C<XML::LibXML> (i.e. A C<XML::LibXML::Element>).

  $cfg = new JAC::OCS::Config::ACSIS::ProcessLinks( File => $file );
  $cfg = new JAC::OCS::Config::ACSIS::ProcessLinks( XML => $xml );
  $cfg = new JAC::OCS::Config::ACSIS::ProcessLinks( DOM => $dom );

A blank object will be created if no arguments are supplied.

=cut

sub new {
  my $self = shift;

  # Now call base class with all the supplied options +
  # extra initialiser
  return $self->SUPER::new( @_, 
			    $JAC::OCS::Config::CfgBase::INITKEY => { 
				                                    ProcessLinks => [],
								   }
			  );
}

=back

=head2 Accessor Methods

=over 4

=item B<links>

Return a list of C<JAC::OCS::Config::ACSIS::ProcessLink> objects.

  @links = $pls->links();
  $pls->links( @links );

Note that you can add to the links or overwrite them all, you cannot change them.

=cut

sub links {
  my $self = shift;
  if (@_) {
      @{$self->{ProcessLinks}} = @_;
  }
  return @{$self->{ProcessLinks}};
}

=item B<addLink>

Add a C<JAC::OCS::Config::ACSIS::ProcessLink> object to the list of links.

  my $link = JAC::OCS::Config::ACSIS::ProcessLink(from_ref   => 'if_monitor',
						  from_event => 'if_data',
						  to_ref     => 'sync1',
						  to_event   => 'if_data');
  $pls->addLink( $link );

=cut

sub addLink {
  my $self = shift;
  if (@_) {
    push(@{$self->{ProcessLinks}}, @_);
  }
}

=item B<stringify>

Create XML representation of object.

=cut

sub stringify {
  my $self = shift;
  my %args = @_;

  my $xml = '';
  $xml .= "<". $self->getRootElementName . ">\n";

  # Version declaration
  $xml .= $self->_introductory_xml();

  my @links = $self->links;

  for my $link (@links) {
    $xml .= "<glish_link ";
    $xml .= "from_ref=\"".$link->from_ref ."\" ";
    $xml .= "from_event=\"".$link->from_event ."\" ";
    $xml .= "to_ref=\"".$link->to_ref ."\" ";
    $xml .= "to_event=\"".$link->to_event ."\"/>\n";
  }

  $xml .= "</". $self->getRootElementName .">\n";
  return ($args{NOINDENT} ? $xml : indent_xml_string( $xml ));
}

=back

=head2 Class Methods

=over 4

=item B<getRootElementName>

Return the name of the _CONFIG element that should be the root
node of the XML tree corresponding to the ACSIS process link config.

 @names = $h->getRootElementName;

=cut

sub getRootElementName {
  return( "process_links" );
}

=back

=begin __PRIVATE_METHODS__

=head2 Private Methods

=over 4

=item B<_process_dom>

Using the C<_rootnode> node referring to the top of the Instrument XML,
process the DOM tree and extract all the coordinate information.

 $self->_process_dom;

Populates the object with the extracted results.

=cut

sub _process_dom {
  my $self = shift;

  # Find all the header items
  my $el = $self->_rootnode;

  # need to get all the rest_frequency elements.
  my @xmllinks = find_children( $el, "glish_link", min => 1 );

  my @links;
  for my $xmllink (@xmllinks) {
    my %attr = find_attr( $xmllink, "from_ref", "from_event", "to_ref", "to_event" );

    @links = (@links, new JAC::OCS::Config::ACSIS::ProcessLink(%attr));
  }

  # store the links
  $self->links( @links );

}

=back

=end __PRIVATE_METHODS__

=head1 XML SPECIFICATION

The ACSIS XML configuration specification is documented in
OCS/ICD/005 with a DTD available at
http://docs.jach.hawaii.edu/JCMT/OCS/ICD/005/acsis.dtd.

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>, Walther Zwart E<lt>w.zwart@jach.hawaii.eduE<gt>

Copyright (C) 2004 Particle Physics and Astronomy Research Council.
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
