package JAC::OCS::Config::TCS::obsArea;

=head1 NAME

JAC::OCS::Config::TCS::obsArea - Parse and modify TCS observing area

=head1 SYNOPSIS

  use JAC::OCS::Config::TCS::obsArea;

  $cfg = new JAC::OCS::Config::TCS::obsArea( File => 'obsArea.ent');
  $cfg = new JAC::OCS::Config::TCS::obsArea( XML => $xml );
  $cfg = new JAC::OCS::Config::TCS::obsArea( DOM => $dom );

  $pa       = $cfg->posang;
  @offsets  = $cfg->offsets;


=head1 DESCRIPTION

This class can be used to parse and modify the telescope observing area
XML.

=cut

use 5.006;
use strict;
use Carp;
use warnings;
use XML::LibXML;
use Data::Dumper;

use Astro::Coords::Angle;

use JAC::OCS::Config::Error;
use JAC::OCS::Config::Helper qw/ check_class_fatal check_class /;
use JAC::OCS::Config::XMLHelper qw/ find_children find_attr 
				    indent_xml_string
				    /;
use JAC::OCS::Config::TCS::Generic qw/ find_pa find_offsets 
				       pa_to_xml offset_to_xml /;

use base qw/ JAC::OCS::Config::CfgBase /;

use vars qw/ $VERSION /;

$VERSION = sprintf("%d", q$Revision$ =~ /(\d+)/);

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new obsArea configuration object. An object can be created from
a file name on disk, a chunk of XML in a string or a previously created
DOM tree generated by C<XML::LibXML> (i.e. A C<XML::LibXML::Element>).

  $cfg = new JAC::OCS::Config::obsArea( File => $file );
  $cfg = new JAC::OCS::Config::obsArea( XML => $xml );
  $cfg = new JAC::OCS::Config::obsArea( DOM => $dom );

The constructor will locate the obsArea configuration in 
a C<< obsArea >> element. It will not attempt to verify that it has
a C<< TCS_CONFIG >> element as parent.

The method will die if no arguments are supplied.

=cut

sub new {
  my $self = shift;

  # Now call base class with all the supplied options
  return $self->SUPER::new( @_,
			    $JAC::OCS::Config::CfgBase::INITKEY => { 
								    MAPAREA => {},
								    OFFSETS => [],
								    SCAN => {},
								   }
			  );
}

=back

=head2 Accessor Methods

=over 4

=item B<posang>

The global position angle associated with this observing area.

 $tag = $cfg->posang;
 $cfg->posang( 52.4 );

Stored as an C<Astro::Coords::Angle> object.

Can be undefined if no position angle has been specified.

=cut

sub posang {
  my $self = shift;
  if (@_) {
    $self->{POSANG} = check_class_fatal( "Astro::Coords::Angle", shift);
  }
  return $self->{POSANG};
}

=item B<offsets>

Offsets associated with this observing area. If more than one offset
is present, the observing area is assumed to be multiple pointings.
If one offset is present this could either indicate a single pointed
observation or the offset for a scan. The choice depends on whether
the scan area is defined or not.

  @offsets = $obs->offsets;

  $offsets = $obs->offsets;

In scalar context, returns the first offset.

If offsets are supplied, they are first validated (to make sure they
are C<Astro::Coords::Offset> objects) and then stored in the object,
overwriting previous entries.

=cut

sub offsets {
  my $self = shift;
  if (@_) {
    my @valid = check_class( "Astro::Coords::Offset", @_ );
    warnings::warnif("No offsets passed validation.")
	unless @valid;
    @{$self->{OFFSETS}} = @valid;
  }
  if (wantarray) {
    return @{$self->{OFFSETS}};
  } else {
    # do not want to create an undef entry
    if (scalar @{$self->{OFFSETS}}) {
      return $self->{OFFSETS}->[0];
    } else {
      return undef;
    }
  }
}

=item B<maparea>

Return details of the area to be mapped. Recognized keys are "WIDTH"
and "HEIGHT" which should be specified in arcseconds.

  %a = $obs->maparea();
  $obs->maparea( %a );

=cut

# we do not have a map area object

sub maparea {
  my $self = shift;
  if (@_) {
    my %args = @_;
    for my $k (qw/ WIDTH HEIGHT/) {
      $self->{MAPAREA}->{$k} = $args{$k};
    }
  }
  return %{ $self->{MAPAREA} };
}

=item B<scan>

Specification of how to scan the map area.

  %scan = $obs->scan;
  $obs->scan( %scan );

Allowed keys for hash are VELOCITY, SYSTEM, DY, REVERSAL and TYPE.
Also, PA must be a reference to an array of C<Astro::Coords::Angle>
objects.

REVERSAL should be a boolean rather than a "YES" or "NO".

=cut

# we do not have a scan specification object

sub scan {
  my $self = shift;
  if (@_) {
    my %args = @_;
    for my $k (qw/ VELOCITY SYSTEM DY REVERSAL TYPE PA /) {
      $self->{SCAN}->{$k} = $args{$k};
    }
  }
  return %{ $self->{SCAN} };
}

=item B<scan_pattern>

Return the name of the scan pattern.

  $name = $oa->scan_pattern();

Returns undef if the oberving area is not a scan.

Recognized patterns are:

  RASTER         (normal raster with scan reversal false)
  BOUSTROPHEDON  (raster with scan reversal true)

=cut

sub scan_pattern {
  my $self = shift;

  if ( $self->mode eq 'area' ) {
    my %scan = $self->scan;
    # Absence of REVERSAL means "YES"
    my $rev = $scan{REVERSAL};
    if (!defined $rev || $rev ) {
      return "BOUSTROPHEDON";
    } else {
      return "RASTER";
    }
  } else {
    return undef;
  }
}

=item B<mode>

Return the type of observing area that has been specified.
Can be either "offsets" or "area".

=cut

sub mode {
  my $self = shift;

  my $mode = '';
  if ($self->maparea) {
    $mode = "area";
  } elsif ($self->offsets) {
    $mode = "offsets";
  } else {
    croak "obsArea must be either offsets or map area";
  }
  return $mode;
}

=item B<stringify>

Convert the object back into XML.

  $xml = $obs->stringify( NOINDENT => 1);

=cut

sub stringify {
  my $self = shift;
  my %args = @_;
  my $xml = "";

  $xml .= "<". $self->getRootElementName . ">\n";

  # Version declaration
  $xml .= $self->_introductory_xml();

  # position angle for the area
  if (defined $self->posang) {
    $xml .= pa_to_xml( $self->posang );
  }

  # get the mode
  my $mode = $self->mode;

  if ($mode eq 'offsets') {
    for my $o ($self->offsets) {
      $xml .= offset_to_xml( $o );
    }
  } elsif ($mode eq 'area') {
    $xml .= "<SCAN_AREA>\n";

    my @o = $self->offsets;
    $xml .= offset_to_xml( $o[0] ) if @o;

    my %area = $self->maparea;

    $xml .= "<AREA HEIGHT=\"$area{HEIGHT}\" WIDTH=\"$area{WIDTH}\" />\n";

    my %scan = $self->scan;
    $xml .= "<SCAN VELOCITY=\"$scan{VELOCITY}\"\n";
    $xml .= "      SYSTEM=\"$scan{SYSTEM}\"\n" if defined $scan{SYSTEM};
    $xml .= "      DY=\"$scan{DY}\"\n";
    $xml .= "      REVERSAL=\"".
      ($scan{REVERSAL} ? "YES" : "NO" )."\"\n" if defined $scan{REVERSAL};
    $xml .= "      TYPE=\"$scan{TYPE}\"" if defined $scan{TYPE};
    $xml .= " >\n";

    for my $pa (@{ $scan{PA} }) {
      $xml .= pa_to_xml( $pa );
    }

    $xml .= "</SCAN>\n";

    $xml .= "</SCAN_AREA>\n";
  } else {
    croak "Unrecognized obsArea mode '$mode'";
  }

  $xml .= "</". $self->getRootElementName .">\n";

  return ($args{NOINDENT} ? $xml : indent_xml_string( $xml ));
}

=back

=head2 Class Methods

=over 4

=item B<getRootElementName>

Return the name of the element that should be the root
node of the XML tree corresponding to the TCS obsArea config.

 @names = $tcs->getRootElementName;

=cut

sub getRootElementName {
  return( "obsArea" );
}

=back

=begin __PRIVATE_METHODS__

=head2 Private Methods

=over 4

=item B<_process_dom>

Using the C<_rootnode> node referring to the top of the TCS XML,
process the DOM tree and extract all the coordinate information.

 $self->_process_dom;

Populates the object with the extracted results.

=cut

sub _process_dom {
  my $self = shift;

  # parse obsArea

  # Find the position angle
  $self->_find_posang();

  # Find any offsets
  $self->_find_offsets();

  # Find any scan area
  # Noting that there will either be offsets at this level
  # or a scan area, not both
  $self->_find_scan_area();

  return;
}

=item B<_find_posang>

Extract the position angle information if it
exists and store them in the object.

=cut

sub _find_posang {
  my $self = shift;

  # Should only be one PA here
  my @pa = find_pa( $self->_rootnode,
		    max => 1,
		    min => 0,
		  );

  # store the angle
  $self->posang( $pa[0] ) if @pa;

}

=item B<_find_offsets>

Find offsets in the top level. These will be distinct pointing centres
rather than scan area offsets.

=cut

sub _find_offsets {
  my $self = shift;
  my @offsets = find_offsets( $self->_rootnode );

  # Store them
  $self->offsets( @offsets ) if @offsets;

}

=item B<_find_scan_area>

The scan area defines a raster map. It can include an offset,
and must include an area specification, and a scan specification.

=cut

sub _find_scan_area {
  # Not clear if we should be creating a scan area object or not
  my $self = shift;
  my $root = $self->_rootnode;

  # Find the SCAN_AREA
  my $scanarea = find_children( $root, "SCAN_AREA", max => 1);
  return unless $scanarea;

  # We now have a scan area element
  # Find the optional offset
  my @off = find_offsets( $scanarea, min => 0, max => 1 );
  $self->offsets( @off ) if @off;

  # Area specification
  my $area = find_children( $scanarea, "AREA", min => 1, max => 1);
  my %area_info = find_attr( $area, "WIDTH", "HEIGHT" );
  $self->maparea( %area_info );

  # Scan specification
  my $scan = find_children( $scanarea, "SCAN", min => 1, max => 1);

  # Attributes of scan
  my %scan_info = find_attr( $scan, 
			     "VELOCITY","SYSTEM","DY","REVERSAL",
			     "TYPE");

  # Allowed position angles of scan
  my @spa = find_pa( $scan, min => 1);
  $self->scan( %scan_info, PA => \@spa);

  return;
}

=back

=end __PRIVATE_METHODS__

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
