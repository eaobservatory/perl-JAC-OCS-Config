package JAC::OCS::Config::TCS;

=head1 NAME

JAC::OCS::Config::TCS - Parse and modify TCS TOML configuration information

=head1 SYNOPSIS

  use JAC::OCS::Config::TCS;

  $cfg = new JAC::OCS::Config::TCS( File => 'tcs.xml');
  $cfg = new JAC::OCS::Config::TCS( XML => $xml );
  $cfg = new JAC::OCS::Config::TCS( DOM => $dom );

  $base  = $cfg->getTarget;
  $guide = $cfg->getCoords( 'GUIDE' );

=head1 DESCRIPTION

This class can be used to parse and modify the telescope configuration
information present in either the C<TCS_CONFIG> element of a
standalone configuration file, or the C<SpTelescopeObsComp> element of
a standard TOML file.

=cut

use 5.006;
use strict;
use Carp;
use warnings;
use XML::LibXML;
use Astro::SLA;
use Astro::Coords;
use Astro::Coords::Offset;
use Data::Dumper;

use JAC::OCS::Config::Error;
use JAC::OCS::Config::TCS::BASE;

use base qw/ JAC::OCS::Config::CfgBase /;

use vars qw/ $VERSION /;

$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new TCS configuration object. An object can be created from
a file name on disk, a chunk of XML in a string or a previously created
DOM tree generated by C<XML::LibXML> (i.e. A C<XML::LibXML::Element>).

  $cfg = new JAC::OCS::Config::TCS( File => $file );
  $cfg = new JAC::OCS::Config::TCS( XML => $xml );
  $cfg = new JAC::OCS::Config::TCS( DOM => $dom );

The constructor will locate the TCS configuration in either a
SpTelescopeObsComp element (the element used in the TOML XML dialect
to represent a target in the JAC Observing Tool) or TCS_CONFIG element
(JAC/JCMT configuration files).

The method will die if no arguments are supplied.

=cut

sub new {
  my $self = shift;

  # Now call base class with all the supplied options +
  # extra initialiser
  return $self->SUPER::new( @_, 
			    $JAC::OCS::Config::CfgBase::INITKEY => { 
								    TAGS => {}
								   }
			  );
}

=head2 Accessor Methods

=over 4

=item B<telescope>

The name of the telescope. This is present as an attribute to the TCS_CONFIG
element. If this class is reading TOML the telescope will not be defined.

=cut

sub telescope {
  my $self = shift;
  if (@_) { $self->{Telescope} = shift;}
  return $self->{Telescope};
}

=item B<tags>

Hash containing the tags used in the TCS configuration as keys and the
corresponding coordinate information.

  my %tags = $cfg->tags;
  $cfg->tags( %tags );

The content of this hash is not part of the public interface. Use the
getCoords, getOffsets and getTrackingSystem methods for detailed
information.

=cut

sub tags {
  my $self = shift;
  if (@_) {
    %{ $self->{TAGS} } = @_;
  }
  return %{ $self->{TAGS} };
}

=item B<isBlank>

Returns true if the object refers to a default position of 0h RA, 0 deg Dec
and blank target name.

=cut

sub isBlank {
  croak "Must implement this";
}

=item B<getTarget>

Retrieve the Base or Science position as an C<Astro::Coords> object.

  $c = $cfg->getTarget;

Note that it is an error for there to be both a Base and a Science
position in the XML.

Also note that C<Astro::Coords> objects do not currently support
OFFSETS and so any offsets present in the XML will not be present in
the returned object. See the C<getTargetOffset> method.

=cut

sub getTarget {
  my $self = shift;
  return $self->getCoords("SCIENCE");
}


=item B<getCoords>

Retrieve the coordinate object associated with the supplied
tag name. Returns C<undef> if the specified tag is not present.

  $c = $cfg->getCoords( 'SCIENCE' );

The following synonyms are supported:

  BASE <=> SCIENCE
  REFERENCE <=> SKY

BASE/SCIENCE is equivalent to calling the C<getTarget> method.

Note that C<Astro::Coords> objects do not currently support OFFSETS
and so any offsets present in the XML will not be present in the
returned object. See the C<getOffset> method.

=cut

sub getCoords {
  my $self = shift;
  my $tag = shift;

  my %tags = $self->tags;

  # look for matching key or synonym
  $tag = $self->_translate_tag_name( $tag );

  return (defined $tag ? $tags{$tag}->coords : undef );
}

=item B<getTargetOffset>

Wrapper for C<getOffset> method. Returns any offset associated
with the base/science position.

=cut

sub getTargetOffset {
  my $self = shift;
  return $self->getOffset( "SCIENCE" );
}

=item B<getOffset>

Retrieve any offset associated with the specified target. Offsets are
returned as a C<Astro::Coords::Offset> objects.
Can return undef if no offset was specified.

  $ref = $cfg->getOffset( "SCIENCE" );

This method may well be obsoleted by an upgrade to C<Astro::Coords>.

=cut

sub getOffset {
  my $self = shift;
  my $tag = shift;

  my %tags = $self->tags;

  # look for matching key or synonym
  $tag = $self->_translate_tag_name( $tag );

  return (defined $tag ? $tags{$tag}->offset : undef );
}

=item B<getTrackingSystem>

Each Base position can have a different tracking system to the start
position specified in the target. (for example, a position can be
specified in RA/Dec but the telescope can be told to track in AZEL)

  $track_sys = $cfg->getTrackingSystem( "REFERENCE" );

=cut

sub getTrackingSystem {
  my $self = shift;
  my $tag = shift;

  my %tags = $self->tags;

  # look for matching key or synonym
  $tag = $self->_translate_tag_name( $tag );

  return (defined $tag ? $tags{$tag}->tracking_system : undef );
}

=back

=head2 Class Methods

=over 4

=item B<getRootElementName>

Return the name of the _CONFIG element that should be the root
node of the XML tree corresponding to the TCS config.
Returns two node names (one for TOML and one for TCS_CONFIG).

 @names = $tcs->getRootElementName;

=cut

sub getRootElementName {
  return( "TCS_CONFIG", "SpTelescopeObsComp" );
}



=back

=begin __PRIVATE_METHODS__

=head2 Private Methods

=over 4

=item B<_translate_tag_name>

Given  a tag name, check to see whether a tag of that name exists. If it does, return it, if it doesn't look up the tag name in the synonyms table. If the sysnonym exists, return that. Else return undef.

 $tag = $cfg->_translate_tag_name( $tag );

=cut

{
  my %synonyms = ( BASE => 'SCIENCE',
		   SCIENCE => 'BASE',
		   REFERENCE => 'SKY',
		   SKY => 'REFERENCE',
		 );


  sub _translate_tag_name {
    my $self = shift;
    my $tag = shift;

    my %tags = $self->tags;

    if (exists $tags{$tag} ) {
      return $tag;
    } elsif (exists $synonyms{$tag} && exists $tags{ $synonyms{$tag} } ) {
      # Synonym exists
      return $synonyms{$tag};
    } else {
      return undef;
    }
  }
}

=item B<_process_dom>

Using the C<_rootnode> node referring to the top of the TCS XML,
process the DOM tree and extract all the coordinate information.

 $self->_process_dom;

Populates the object with the extracted results.

=cut

sub _process_dom {
  my $self = shift;

  # Get the telescope name (if possible)
  $self->_find_telescope();

  # Look for BASE positions
  $self->_find_base_posns();

  # SLEW settings

  # Observing Area

  # Secondary mirror configuration

  # Beam rotator configuration

  return;
}

=item B<_find_telescope>

Extract telescope name from the DOM tree. Non-fatal if a telescope
can not be located.

The object is updated if a telescope is located.

=cut

sub _find_telescope {
  my $self = shift;
  my $el = $self->_rootnode;

  my $tel = $el->getAttribute( "TELESCOPE" );

  $self->telescope( $tel ) if $tel;
}

=item B<_find_base_posns>

Extract target information from the BASE elements in the TCS.
An exception will be thrown if no base positions can be found.

  $cfg->_find_base_posns();

The state of the object is updated.

=cut

sub _find_base_posns {
  my $self = shift;
  my $el = $self->_rootnode;

  # We need to parse each of the BASE positions specified
  # Usually SCIENCE, REFERENCE or BASE and SKY

  # We should find all the BASE entries and parse them in turn.
  # Note that we have to look out for both BASE (the modern form)
  # and "base" the old-style.

  my @base = $el->findnodes( './/BASE | .//base ');

  # Throw an exception if we did not find anything since a base
  # position is mandatory
  throw JAC::OCS::Config::Error::XMLBadStructure("No base target position specified in TCS XML\n")
    unless @base;

  # For each of these nodes we need to extract the target information
  # and the tag
  my %tags;
  for my $b (@base) {

    # Create the object from the dom.
    my $base = new JAC::OCS::Config::TCS::BASE( DOM => $b );
    my $tag = $base->tag;
    $tags{$tag} = $base;

  }

  # Store the coordinate information
  $self->tags( %tags );

}

=end __PRIVATE_METHODS__

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
