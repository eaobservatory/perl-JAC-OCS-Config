package JAC::OCS::Config::Frontend;

=head1 NAME

JAC::OCS::Config::Frontend - Parse and modify OCS frontend configurations

=head1 SYNOPSIS

  use JAC::OCS::Config::Frontend;

  $cfg = new JAC::OCS::Config::Frontend( File => 'fe.ent');

=head1 DESCRIPTION

This class can be used to parse and modify the frontend configuration
information present in the FRONTEND_CONFIG element of an OCS configuration.

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
				   indent_xml_string
				   get_pcdata_multi
				  );


use base qw/ JAC::OCS::Config::CfgBase /;

use vars qw/ $VERSION /;

$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

# map real instrument name to frontend task name
our %TASKMAP = (
		RXA3 => 'FE_A',
		RXB3 => 'FE_B',
		RXWC => 'FE_W',
		RXWD => 'FE_W',
		HARPB => 'FE_HARPB',
		);


=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new Frontend configuration object. An object can be created from
a file name on disk, a chunk of XML in a string or a previously created
DOM tree generated by C<XML::LibXML> (i.e. A C<XML::LibXML::Element>).

  $cfg = new JAC::OCS::Config::Frontend( File => $file );
  $cfg = new JAC::OCS::Config::Frontend( XML => $xml );
  $cfg = new JAC::OCS::Config::Frontend( DOM => $dom );

The method will die if no arguments are supplied.

=cut

sub new {
  my $self = shift;

  # Now call base class with all the supplied options +
  # extra initialiser
  return $self->SUPER::new( @_, 
			    $JAC::OCS::Config::CfgBase::INITKEY => { 
								    MASK => {},
								    DOPPLER => {},
								   }
			  );
}

=back

=head2 Accessor Methods

=over 4

=item B<tasks>

Task or tasks that will be configured from this XML.

 @tasks = $cfg->tasks;

=cut

sub tasks {
  my $self = shift;
  my $name = $self->frontend;

  # if we already named FE_XXX that is the task name
  if ($name =~ /^FE_/) {
    return ($name);
  } elsif (exists $TASKMAP{$name}) {
    return $TASKMAP{$name};
  }
  return ();
}

=item B<frontend>

Name of the frontend associated with this configuration. This will be compared
to the Instrument information specified in the global configuration.

=cut

sub frontend {
  my $self = shift;
  if (@_) {
    $self->{FRONTEND_NAME} = shift;
  }
  return $self->{FRONTEND_NAME};
}

=item B<rest_frequency>

Rest frequency. GHz.

=cut

sub rest_frequency {
  my $self = shift;
  if (@_) {
    $self->{REST_FREQUENCY} = shift;
  }
  return $self->{REST_FREQUENCY};
}

=item B<freq_off_scale>

Frequency offset scaling.

=cut

sub freq_off_scale {
  my $self = shift;
  if (@_) {
    $self->{FREQ_OFF_SCALE} = shift;
  }
  return $self->{FREQ_OFF_SCALE};
}

=item B<sideband>

Selected sideband (USB or LSB).

=cut

sub sideband {
  my $self = shift;
  if (@_) {
    $self->{SIDEBAND} = uc(shift);
  }
  return $self->{SIDEBAND};
}


=item B<sb_mode>

Sideband mode (only relevant for dual sideband instruments).
Can be SSB or DSB.

=cut

sub sb_mode {
  my $self = shift;
  if (@_) {
    $self->{SB_MODE} = uc(shift);
  }
  return $self->{SB_MODE};
}

=item B<optimize>

Optimization setting. ENABLE or DISABLE.

=cut

sub optimize {
  my $self = shift;
  if (@_) {
    $self->{OPTIMIZE} = shift;
  }
  return $self->{OPTIMIZE};
}


=item B<doppler>

Hash representing Doppler tracking configuration. Allowed keys are
ELEC_TUNING and MECH_TUNING, each of which can have values of
"CONTINUOUS", "DISCRETE", "GROUP", "ONCE" or "NONE".

  %dop = $fe->doppler;
  $fe->doppler( %dop );

=cut

sub doppler {
  my $self = shift;
  if (@_) {
    %{$self->{DOPPLER}} = @_;
  }
  return %{$self->{DOPPLER}};
}


=item B<mask>

Hash containing the state of each receptor for the configuration.

  %mask = $fe->mask;
  $fe->mask( %mask );

Keys are the receptor IDs, values are "ON", "OFF" or "NEED".

=cut

sub mask {
  my $self = shift;
  if (@_) {
    %{$self->{MASK}} = @_;
  }
  return %{$self->{MASK}};
}

=item B<stringify>

Create XML representation of object.

=cut

sub stringify {
  my $self = shift;
  my %args = @_;

  my $xml = '';

  $xml .= "<FRONTEND_CONFIG>\n";

  # Version declaration
  $xml .= $self->_introductory_xml();

  # The mandatory keywords
  my $rfreq = $self->rest_frequency;
  throw JAC::OCS::Config::Error::FatalError( 'Must supply rest frequency in order to create XML') unless defined $rfreq;
  $xml .= "<REST_FREQUENCY>". $rfreq ."</REST_FREQUENCY>\n";
  $xml .= "<FREQ_OFF_SCALE>". (defined $self->freq_off_scale ?
			       $self->freq_off_scale : 0).
				 "</FREQ_OFF_SCALE>\n";
  throw JAC::OCS::Config::Error::FatalError( 'Must supply sideband in order to create XML') unless defined $self->sideband;

  $xml .= "<SIDEBAND>". $self->sideband ."</SIDEBAND>\n";

  $xml .= "<SB_MODE>". $self->sb_mode ."</SB_MODE>\n"
    if defined $self->sb_mode;

  my %dop = $self->doppler;
  if (keys %dop) {
    $xml .= "<DOPPLER_TRACK ELEC_TUNING=\"".$dop{ELEC_TUNING}."\"\n";
    $xml .= "               MECH_TUNING=\"".$dop{MECH_TUNING}."\" />\n";
  }

  $xml .= "<OPTIMIZE>". $self->optimize ."</OPTIMIZE>\n"
    if defined $self->optimize;


  my %mask = $self->mask;

  for my $r (sort keys %mask) {
    $xml .= "<RECEPTOR_MASK RECEPTOR_ID=\"$r\" VALUE=\"$mask{$r}\"/>\n";
  }

  $xml .= "</FRONTEND_CONFIG>\n";
  return ($args{NOINDENT} ? $xml : indent_xml_string( $xml ));
}

=back

=head2 Class Methods

=over 4

=item B<dtdrequires>

Returns the names of any associated configurations required for this
configuration to be used in a full OCS_CONFIG. The frontend requires
'instrument_setup'.

  @requires = $cfg->dtdrequires();

=cut

sub dtdrequires {
  return ('instrument_setup');
}

=item B<getRootElementName>

Return the name of the _CONFIG element that should be the root
node of the XML tree corresponding to the Frontend config.

 @names = $h->getRootElementName;

=cut

sub getRootElementName {
  return( "FRONTEND_CONFIG" );
}

=back

=begin __PRIVATE_METHODS__

=head2 Private Methods

=over 4

=item B<_process_dom>

Using the C<_rootnode> node referring to the top of the Frontend XML,
process the DOM tree and extract all the coordinate information.

 $self->_process_dom;

Populates the object with the extracted results.

=cut

sub _process_dom {
  my $self = shift;

  # Find all the header items
  my $el = $self->_rootnode;

  # Find the mandatory items
  my @names = qw/ REST_FREQUENCY FREQ_OFF_SCALE SIDEBAND /;
  my %mandatory = get_pcdata_multi( $el, @names);

  for my $k (@names) {
    throw JAC::OCS::Config::Error::XMLEmpty("FRONTEND_CONFIG is missing element '$k'") unless exists $mandatory{$k};
    my $method = lc($k);
    $self->$method( $mandatory{$k} );
  }

  # Optional items. Note that FRONTEND_CONFIG does not contain
  # explicit information as to the associated frontend so we can not
  # verify that SB_MODE is reasonable. Could infer from the RECEPTOR_ID.
  my @opt = qw/ SB_MODE OPTIMIZE /;
  my %optional = get_pcdata_multi( $el, @opt);
  $self->sb_mode( $optional{SB_MODE} );
  $self->optimize( $optional{OPTIMIZE} );

  # Doppler tracking uses attributes
  my $doppler = find_children( $el, "DOPPLER_TRACK", min => 1, max => 1);
  my %dopp = find_attr( $doppler, "MECH_TUNING","ELEC_TUNING");
  $self->doppler( %dopp );

  # Mask
  $self->_process_mask();

  return;
}

=item B<_process_mask>

Process all the RECEPTOR_MASK XML. and configure the mask() method in the
object.

  $cfg->_process_mask();

=cut

sub _process_mask {
  my $self = shift;

  # Find all the header items
  my $el = $self->_rootnode;

  # Receptor Mask
  my @masks = find_children( $el, "RECEPTOR_MASK", min => 1);
  my %mask;
  for my $m (@masks) {
    my %attr = find_attr( $m, "RECEPTOR_ID", "VALUE");
    $mask{$attr{RECEPTOR_ID}} = $attr{VALUE};
  }
  $self->mask( %mask );

}

=back

=end __PRIVATE_METHODS__

=head1 XML SPECIFICATION

The frontend XML configuration specification is documented in
OCS/ICD/004 with a DTD available at
http://www.jach.hawaii.edu/JACdocs/JCMT/OCS/ICD/004/frontend_configure.dtd.

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
