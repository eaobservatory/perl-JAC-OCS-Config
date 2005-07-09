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

use JAC::OCS::Config::Error qw| :try |;
use JAC::OCS::Config::Helper qw/ check_class_fatal /;
use JAC::OCS::Config::XMLHelper qw| find_children find_attr
				    indent_xml_string
				    |;
use JAC::OCS::Config::TCS::Generic qw| find_pa pa_to_xml offset_to_xml |;

use JAC::OCS::Config::TCS::BASE;
use JAC::OCS::Config::TCS::obsArea;
use JAC::OCS::Config::TCS::Secondary;

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

A telescope can be specified explicitly in the constructor if desired.
This should only be relevant when parsing SpTelescopeObsComp XML.

  $cfg = new JAC::OCS::Config::TCS( XML => $xml,
                                    telescope => 'JCMT' );

The method will die if no arguments are supplied.

=cut

sub new {
  my $self = shift;
  my %args = @_;

  # extract telescope
  my $tel = $args{telescope};
  delete $args{telescope};

  # Now call base class with all the supplied options +
  # extra initialiser
  return $self->SUPER::new( %args,
			    $JAC::OCS::Config::CfgBase::INITKEY => { 
								    Telescope => $tel,
								    TAGS => {},
								    SLEW => {},
								    ROTATOR => {},
								   }
			  );
}

=back

=head2 Accessor Methods

=over 4

=item B<isConfig>

Returns true if this object is derived from a TCS_CONFIG, false
otherwise (e.g if it is derived from a TOML configuration or not
derived from a DOM at all).

=cut

sub isConfig {
  my $self = shift;
  my $root = $self->_rootnode;

  my $name = $root->nodeName;
  return ( $name =~ /_CONFIG/ ? 1 : 0);
}

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

All tags can be removed by supplying a single undef

  $cfg->tags( undef );

See C<clearAllCoords> for the public implementation/

In scalar context returns the hash reference:

  $ref = $cfg->tags;

Currently, the values in the tags hash are C<JAC::OCS::Config::TCS::BASE>
objects.

=cut

sub tags {
  my $self = shift;
  if (@_) {
    # undef is a special case to clear all tags
    my @args = @_;
    @args = () unless defined $args[0];
    %{ $self->{TAGS} } = @_;
  }
  return (wantarray ? %{ $self->{TAGS} } : $self->{TAGS} );
}

=item B<slew>

Slewing options define how the telescope will slew to the science target
for the first slew of a configuration.

  $cfg->slew( %options );
  %options = $cfg->slew;

Allowed keys are OPTION, TRACK_TIME and CYCLE.

If OPTION is set, it will override any TRACK_TIME and CYCLE implied
definition.

If TRACK_TIME is set, OPTION will be set to 'TRACK_TIME' if OPTION is unset.

If CYCLE is set, OPTION will be set to 'TRACK_TIME' if OPTION is unset.

If OPTION is unset, but both TRACK_TIME and CYCLE are set, an error will be
triggered when the XML is created.

Default slew option is SHORTEST_SLEW.

Currently no validation is performed on the values of the supplied hash.

=cut

sub slew {
  my $self = shift;
  if (@_) {
    %{ $self->{SLEW} } = @_;
  }
  return %{ $self->{SLEW} };
}

=item B<rotator>

Image rotator options. This can be undefined.

  $cfg->rotator( %options );
  %options = $self->rotator;

Allowed keys are SLEW_OPTION, MOTION, SYSTEM and PA.
PA must refer to a reference to an array of C<Astro::Coords::Angle>
objects.

Currently no validation is performed on the values of the supplied hash.

=cut

sub rotator {
  my $self = shift;
  if (@_) {
    %{ $self->{ROTATOR} } = @_;
  }
  return %{ $self->{ROTATOR} };
}

=item B<isBlank>

Returns true if the object refers to a default position of 0h RA, 0 deg Dec
and blank target name, or alternatively contains zero tags.

=cut

sub isBlank {
  croak "Must implement this";
}

=item B<getTags>

Returns a list of all the coordinate tags available in the object.

  @tags = $cfg->getTags;

=cut

sub getTags {
  my $self = shift;
  my %tags = $self->tags;
  return keys %tags;
}

=item B<getNonSciTags>

Get the non-Science tags that are in use. This allows the science/Base tags
to be extracted using the helper methods, and then the remaining tags to
be processed without worrying about duplication of the primary tag.

=cut

sub getNonSciTags {
  my $self = shift;
  my %tags = $self->tags;
  my @tags = keys %tags;

  my @out = grep { $_ !~ /(BASE|SCIENCE)/i } @tags;
  return @out;
}

=item B<getSciTag>

Obtain the C<JAC::OCS::Config::TCS::BASE> object associated with the
science position.

  $sci = $tcs->getSciTag;

=cut

sub getSciTag {
  my $self = shift;
  my $tag = $self->_translate_tag_name( 'SCIENCE' );
  my %tags = $self->tags;
  return $tags{$tag};
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

=item B<getObsArea>

Return the C<JAC::OCS::Config::TCS::obsArea> associated with this
configuration.

 $obs = $tcs->getObsArea();

=cut

sub getObsArea {
  my $self = shift;
  return $self->{OBSAREA};
}


# internal routine that will not trigger regeneration of XML
sub _setObsArea {
  my $self = shift;
  $self->{OBSAREA} = check_class_fatal( "JAC::OCS::Config::TCS::obsArea", shift);
}

=item B<getSecondary>

Return the C<JAC::OCS::Config::TCS::Secondary> object associated with this
configuration.

 $obs = $tcs->getSecondary();

Can be undefined.

=cut

sub getSecondary {
  my $self = shift;
  return $self->{SECONDARY};
}


# internal routine that will not trigger regeneration of XML
sub _setSecondary {
  my $self = shift;
  $self->{SECONDARY} = check_class_fatal( "JAC::OCS::Config::TCS::Secondary",shift);
}

=item B<setTarget>

Specifies a new SCIENCE/BASE target.

  $tcs->setTarget( $c );

If a C<JAC::OCS::Config::TCS::BASE> object is supplied, this is stored
directly. If an C<Astro::Coords> object is supplied, it will be stored
in a C<JAC::OCS::Config::TCS::BASE> objects.

Note that offsets can only be included (currently) if an
C<JAC::OCS::Config::TCS::BASE> object is used.

=cut

sub setTarget {
  my $self = shift;
  $self->setCoords( "SCIENCE", shift );
}

=item B<setCoords>

Set the coordinate to be associated with the specified tag.

  $tcs->setCoords( "REFERENCE", $c );

If a C<JAC::OCS::Config::TCS::BASE> object is supplied, this is stored
directly. If an C<Astro::Coords> object is supplied, it will be stored
in a C<JAC::OCS::Config::TCS::BASE> objects.

Note that offsets can only be included (currently) if an
C<JAC::OCS::Config::TCS::BASE> object is used.

=cut

sub setCoords {
  my $self = shift;
  my $tag = shift;
  my $c = shift;

  # look for matching key or synonym
  my $syn = $self->_translate_tag_name( $tag );

  # if we have a translated synonym that means we have an
  # existing tag that we are overwriting. Use that if so, else
  # this is a new tag.
  $tag = $syn if defined $syn;

  # check class
  my $base;
  if ($c->isa( "JAC::OCS::Config::TCS::BASE")) {
    $base = $c;
  } elsif ($c->isa( "Astro::Coords")) {
    $base = new JAC::OCS::Config::BASE();
    $base->coords( $c );
    $base->tag( $tag );
  } elsif ($c->can( "coords") && $c->can( "tag" )) {
    $base = $c;
  } else {
    throw JAC::OCS::Config::Error::BadArgs("Supplied coordinate to setCoords is neither and Astro::Coords nor JAC::OCS::Config::TCS::BASE");
  }

  # store it
  $self->tags->{$tag} = $base;

}

=item B<clearTarget>

Removes the SCIENCE/BASE target.

  $tcs->clearTarget();

=cut

sub clearTarget {
  my $self = shift;
  return $self->clearCoords( "SCIENCE" );
}

=item B<clearCoords>

Clear the target associated with the specified tag.

 $tcs->clearCoords( "REFERENCE" );

Synonyms are supported.

=cut

sub clearCoords {
  my $self = shift;
  my $tag = shift;

  # look for matching key or synonym
  $tag = $self->_translate_tag_name( $tag );

  delete($self->tags->{$tag}) if defined $tag;
}

=item B<clearAllCoords>

Remove all coordinates associated with this object. No tags will be associated
with this object.

 $tcs->clearAllCoords;

=cut

sub clearAllCoords {
  my $self = shift;
  $self->tags( undef );
}

=item B<tasks>

Name of the tasks that would be involved in reading this config.

 @tasks = $tcs->tasks();

Usually 'PTCS' plus SMU if a secondary configuration is available.

=cut

sub tasks {
  my $self = shift;
  my @tasks = ('PTCS');
  push( @tasks, $self->getSecondary->tasks ) if defined $self->getSecondary;
  return @tasks;
}

=item B<stringify>

Convert the class into XML form. This is either achieved simply by
stringifying the DOM tree (assuming object content has not been
changed) or by taking the object attributes and reconstructing the XML.

 $xml = $tcs->stringify;

=cut

sub stringify {
  my $self = shift;
  my %args = @_;

  # Should the <xml> and dtd prolog be included?
  # Should we create a stringified form directly or build a DOM
  # tree and stringify that?
  my $roottag = 'TCS_CONFIG';

  my $xml = '';

  # First the base element
  $xml .= "<$roottag ";

  # telescope
  my $tel = $self->telescope;
  $xml .= "TELESCOPE=\"$tel\"" if $tel;
  $xml .= ">\n";

  # Version declaration
  $xml .= $self->_introductory_xml();

  # Now add the constituents in turn
  $xml .= $self->_toString_base;
  $xml .= $self->_toString_slew;
  $xml .= $self->_toString_obsArea;
  $xml .= $self->_toString_secondary;
  $xml .= $self->_toString_rotator;

  $xml .= "</$roottag>\n";

  # Indent the xml
  return ($args{NOINDENT} ? $xml : indent_xml_string( $xml ));
}

=back

=head2 Class Methods

=over 4

=item B<dtdrequires>

Returns the names of any associated configurations required for this
configuration to be used in a full OCS_CONFIG. The TCS requires
'instrument_setup'.

  @requires = $cfg->dtdrequires();

=cut

sub dtdrequires {
  return ('instrument_setup');
}

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

Given a tag name, check to see whether a tag of that name exists. If
it does, return it, if it doesn't look up the tag name in the synonyms
table. If the synonym exists, return that. Else return undef.

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
  $self->_find_slew();

  # Observing Area
  $self->_find_obsArea();

  # Secondary mirror configuration
  $self->_find_secondary();

  # Beam rotator configuration
  $self->_find_rotator();

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

=item B<_find_slew>

Find the slewing options.

The object is updated if a SLEW is located.

=cut

sub _find_slew {
  my $self = shift;
  my $el = $self->_rootnode;

  # SLEW is now optional (it used to be mandatory for TCS_CONFIG)
  my $slew = find_children( $el, "SLEW", min => 0, max => 1);
  if ($slew) {
    my %sopt = find_attr( $slew, "OPTION", "TRACK_TIME","CYCLE");
    $self->slew( %sopt );
  }

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

  # get the telescope name
  my $tel = $self->telescope;

  # For each of these nodes we need to extract the target information
  # and the tag
  my %tags;
  for my $b (@base) {

    # Create the object from the dom.
    my $base = new JAC::OCS::Config::TCS::BASE( DOM => $b,
						telescope => $tel);
    my $tag = $base->tag;
    $tags{$tag} = $base;

  }

  # Store the coordinate information
  $self->tags( %tags );

}

=item B<_find_obsArea>

Extract observing area information from the XML.

=cut

sub _find_obsArea {
  my $self = shift;
  my $el = $self->_rootnode;

  # since there can only be at most one optional obsArea, pass this rootnode
  # to the obsArea constructor but catch the special case of XMLConfigMissing
  try {
    my $b = 1;
    my $obsa = new JAC::OCS::Config::TCS::obsArea( DOM => $el );
    $self->_setObsArea( $obsa ) if defined $obsa;
  } catch JAC::OCS::Config::Error::XMLConfigMissing with {
    # this error is okay
  };

}

=item B<_find_rotator>

Find the image rotator settings. This field is optional.
The object is updated if a ROTATOR is located.

=cut

sub _find_rotator {
  my $self = shift;
  my $el = $self->_rootnode;

  my $rot = find_children( $el, "ROTATOR", min => 0, max => 1);
  if ($rot) {
    my %ropt = find_attr( $rot, "SYSTEM","SLEW_OPTION", "MOTION");

    # Allow multiple PA children
    my @pa = find_pa( $rot );

    $self->rotator( %ropt,
		    PA => \@pa,
	       );
  }

}

=item B<_find_secondary>

Specifications for the secondary mirror motion during the observation.
The object is update if a SECONDARY element is located.

=cut

sub _find_secondary {
  my $self = shift;
  my $el = $self->_rootnode;

  # since there can only be at most one optional SECONDARY, pass this rootnode
  # to the SECONDARY constructor but catch the special case of XMLConfigMissing
  try {
    my $sec = new JAC::OCS::Config::TCS::Secondary( DOM => $el );
    $self->_setSecondary( $sec ) if defined $sec;
  } catch JAC::OCS::Config::Error::XMLConfigMissing with {
    # this error is okay
  };

}

=back

=head2 Stringification

=over 4

=item _toString_base

Create the target XML (and associated tags).

 $xml = $tcs->_toString_base();

=cut

sub _toString_base {
  my $self = shift;

  # First get the allowed tags
  my %t = $self->tags;

  my $xml = "";
  for my $tag (keys %t) {
    $xml .= $t{$tag}->stringify(NOINDENT => 1);
  }

  return $xml;
}

=item _toString_slew

Create string representation of the SLEW information.

 $xml = $tcs->_toString_slew();

=cut

sub _toString_slew {
  my $self = shift;
  my $xml = '';
  if ($self->isDOMValid("SLEW")) {
    my $el = $self->_rootnode;
    my $slew = find_children( $el, "SLEW", min => 0, max => 1);
    $xml .= $slew->toString if $slew;
  } else {
    # Reconstruct XML
    my %slew = $self->slew;

    # Slew is mandatory and we can default it to match the DTD if we do not
    # have an explicit value
    $xml .= "\n<!-- Set up the SLEW method here -->\n\n";

    # Normalise the hash
    if (!$slew{OPTION}) {
      # no explicit option
      if (defined $slew{CYCLE} && defined $slew{TRACK_TIME}) {
	throw JAC::OCS::Error::FatalError("No explicit Slew option but CYCLE and TRACK_TIME are specified. Please fix ambiguity.");
      } elsif (defined $slew{CYCLE}) {
	$slew{OPTION} = 'CYCLE';
      } elsif (defined $slew{TRACK_TIME}) {
	$slew{OPTION} = 'TRACK_TIME';
      } else {
	# default to longest track
	$slew{OPTION} = 'SHORTEST_SLEW';
      }
    }	
    if ($slew{OPTION} eq 'CYCLE' && !defined $slew{CYCLE}) {
      throw JAC::OCS::Error::FatalError("Slew option says CYCLE but cycle is not specified");
    } elsif ($slew{OPTION} eq 'TRACK_TIME' && !defined $slew{TRACK_TIME}) {
      throw JAC::OCS::Error::FatalError("Slew option says TRACK_TIME but track time is not specified");
    }

    $xml .= "<SLEW OPTION=\"$slew{OPTION}\" ";
    $xml .= "TRACK_TIME=\"$slew{TRACK_TIME}\" "
      if $slew{OPTION} eq 'TRACK_TIME';
    $xml .= "CYCLE=\"$slew{CYCLE}\" "
      if $slew{OPTION} eq 'CYCLE';
    $xml .= " />\n";
  }
  return $xml;
}

=item _toString_obsArea

Create string representation of observing area.

=cut

sub _toString_obsArea {
  my $self = shift;
  my $obs = $self->getObsArea;
  return "\n<!-- Set up observing area here -->\n\n".
    (defined $obs ? $obs->stringify(NOINDENT => 1) : "" );
}

=item _toString_secondary

Create the XML corresponding to the SECONDARY element.

=cut

sub _toString_secondary {
  my $self = shift;
  my $sec = $self->getSecondary;
  return "\n<!-- Set up Secondary mirror behaviour here -->\n\n".
    (defined $sec ? $sec->stringify(NOINDENT => 1) : "" );
}

=item _toString_rotator

Create string representation of the ROTATOR element.

 $xml = $tcs->_toString_rotator();

=cut

sub _toString_rotator {
  my $self = shift;
  my $xml = '';
  if ($self->isDOMValid("ROTATOR")) {
    my $el = $self->_rootnode;
    my $rot = find_children( $el, "ROTATOR", min => 0, max => 1);
    $xml .= $rot->toString if $rot;
  } else {
    # Reconstruct XML
    my %rot = $self->rotator;
    # Check we have something. ROTATOR is an optional element
    $xml .= "\n<!-- Configure the instrument rotator here -->\n\n";
    if (keys %rot) {

       # Check that the slew option is okay
      my %slew = $self->slew;
      if ($rot{SLEW_OPTION} eq 'TRACK_TIME' &&
	  !exists $slew{TRACK_TIME}) {
	throw JAC::OCS::Config::Error::FatalError("Rotator is attempting to use TRACK_TIME slew option but no track time has been defined in the SLEW parameter");
      }

      $xml .= "<ROTATOR SYSTEM=\"$rot{SYSTEM}\"\n";
      $xml .= "         SLEW_OPTION=\"$rot{SLEW_OPTION}\"\n"
	if exists $rot{SLEW_OPTION};
      $xml .= "         MOTION=\"$rot{MOTION}\"\n" 
	if exists $rot{MOTION};
      $xml .= ">\n";

      if (exists $rot{PA}) {
	for my $pa (@{$rot{PA}}) {
	  $xml .= "  ". pa_to_xml( $pa );
	}
      }

      $xml .= "</ROTATOR>\n";

    }
  }
  return $xml;
}

=back

=end __PRIVATE_METHODS__

=head1 XML SPECIFICATION

The TCS XML configuration specification is documented in OCS/ICD/006
with a DTD available at
http://www.jach.hawaii.edu/JACdocs/JCMT/OCS/ICD/006/tcs.dtd. A
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

Copyright 2002-2005 Particle Physics and Astronomy Research Council.
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
