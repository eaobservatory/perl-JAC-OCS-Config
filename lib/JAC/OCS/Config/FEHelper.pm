package JAC::OCS::Config::FEHelper;

=head1 NAME

JAC::OCS::Config::FEHelper - shared frontend routines

=head1 SYNOPSIS

  use JAC::OCS::Config::FEHelper;

  %mask = $fe->process_mask("RECEPTOR", $el );

=head1 DESCRIPTION

The FRONTEND_CONFIG and SCUBA2_CONFIG share xml syntax for specifying
the active detectors (receptor or subarray) for the instrument. This
class provides methods that can be subclassed for obtaining the
information.

Nothing is exported.

=cut

use 5.006;
use strict;

use warnings;

use vars qw/ $VERSION /;

use JAC::OCS::Config::XMLHelper qw(
				   find_children
           find_attr
				  );

$VERSION = 1.0;

=head1 PUBLIC METHODS

=over 4

=item B<mask>

Hash containing the state of each receptor or subarray for the configuration.

  %mask = $fe->mask;
  $fe->mask( %mask );

Keys are the receptor/subarray IDs, values are "ON", "ANY", "OFF" or "NEED".

=cut

sub mask {
  my $self = shift;
  if (@_) {
    %{$self->{MASK}} = @_;
  }
  return %{$self->{MASK}};
}

=back

=head1 PROTECTED METHODS

For subclasses only.

=over 4

=item B<_active_elements>

Returns the list of receptors or subarrays that are active (ie not "OFF").

  @active = $fe->_active_elements();

Will be called by active_receptors() or active_subarrays() method.

=cut

sub _active_elements {
  my $self = shift;
  my %mask = $self->mask;
  my @good = grep { $mask{$_} ne 'OFF' } keys %mask;
  return @good;
}


=item B<process_mask>

Parse MASK xml as used in FRONTEND_CONFIG and SCUBA2_CONFIG. The XML
is of the form

  <XXX_MASK XXX_ID="id"  VALUE="NEED"/>

Returns a hash indexed by id with value read from value.

  $fe->process_mask(); 

The mask is stored in the object and also returned (so there
is no need to call the mask() method to store it.

=cut

sub _process_mask { 
  my $self = shift;

  # Find all the header items
  my $el = $self->_rootnode;

  my $root_name = $self->_mask_xml_name;
  my $idkey = $root_name . "_ID";
  my $maskkey = $root_name . "_MASK";

  # Receptor Mask
  my @masks = find_children( $el, $maskkey, min => 1);
  my %mask;
  for my $m (@masks) {
    my %attr = find_attr( $m, $idkey, "VALUE");
    JAC::OCS::Config::Error::XMLBadStructure->throw("$idkey not present")
        unless (exists $attr{$idkey} &&
                defined $attr{$idkey});
    $mask{$attr{$idkey}} = $attr{VALUE};
  }
  $self->mask( %mask );
  return %mask;
}

=item B<_stringify_mask>

Returns the XML representation of the mask.

  $xml = $s2->_stringify_mask();

=cut

sub _stringify_mask {
  my $self = shift;
  
  my %mask = $self->mask;
  my $root_name = $self->_mask_xml_name;

  my $xml = '';
  for my $r (sort keys %mask) {
    $xml .= "<".$root_name."_MASK ".
      $root_name."_ID=\"$r\" VALUE=\"$mask{$r}\"/>\n";
  }
  return $xml;
}


=back

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

Copyright 2008 Science and Technology Facilities Council.
Copyright 2004-2007 Particle Physics and Astronomy Research Council.
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
