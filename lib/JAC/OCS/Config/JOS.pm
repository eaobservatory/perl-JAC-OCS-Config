package JAC::OCS::Config::JOS;

=head1 NAME

JAC::OCS::Config::Header - Parse and modify OCS JOS configurations

=head1 SYNOPSIS

  use JAC::OCS::Config::Header;

  $cfg = new JAC::OCS::Config::Header( File => 'jos.ent');

=head1 DESCRIPTION

This class can be used to parse and modify the header configuration
information present in the JOS_CONFIG element of an OCS configuration.

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
				   get_pcdata
				  );

use JAC::OCS::Config::Header::Item;

use base qw/ JAC::OCS::Config::CfgBase /;

use vars qw/ $VERSION /;

$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

# List of all recipe parameters
# Should be extended to include corresponding recipe names
our @PARAMS = (qw/
		  NUM_CYCLES
		  NUM_NOD_SETS
		  STEP_TIME
		  JOS_MULT
		  JOS_MIN
		  ROWS_PER_REF
		  REFS_PER_CAL
		  N_REFSAMPLES
		  N_CALSAMPLES
		  N_SKYREFSAMPLES
		  FOCUS_STEPS
		  FOCUS_STEP
		  /);

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new JOS configuration object. An object can be created from
a file name on disk, a chunk of XML in a string or a previously created
DOM tree generated by C<XML::LibXML> (i.e. A C<XML::LibXML::Element>).

  $cfg = new JAC::OCS::Config::Header( File => $file );
  $cfg = new JAC::OCS::Config::Header( XML => $xml );
  $cfg = new JAC::OCS::Config::Header( DOM => $dom );

The method will die if no arguments are supplied.

=cut

sub new {
  my $self = shift;

  # Now call base class with all the supplied options +
  # extra initialiser
  return $self->SUPER::new( @_, 
			    $JAC::OCS::Config::CfgBase::INITKEY => { 
								    TASKS => [],
								   }
			  );
}

=back

=head2 Accessor Methods

=over 4

=item B<tasks>

Tasks participating in this configuration, in the order in which they
appear in the config file.

  @t = $h->tasks;
  $h->tasks( @t );

=cut

sub tasks {
  my $self = shift;
  if (@_) {
    @{$self->{TASKS}} = @_;
  }
  return @{$self->{TASKS}};
}

=item B<recipe>

Name of the recipe.

=cut

sub recipe {
  my $self = shift;
  if (@_) {
    $self->{RECIPE} = shift;
  }
  return $self->{RECIPE};
}

=item B<parameters>

Recipe parameters (as a hash). Parameters should be upper-cased. This
is a wrapper for the independent accessor methods but limits the
return parameters to those that are relevant for the registered
recipe.

 %par = $jos->parameters;
 $jos->parameters( %par );

If hash arguments are provided to this method, the values will be delegated to
the corresponding parameter methods.

=cut

sub parameters {
  my $self = shift;
  if (@_) {
    my %input = @_;
    for my $p (keys %input) {
      my $method = lc($p);
      $self->$method( $input{$p} ) if $self->can( $method );
    }
  }
  # return all relevant parameters
  my %output;
  for my $p (@PARAMS) {
    my $method = lc($p);
    # if defined
    my $val= $self->$method() if $self->can($method);
    $output{$p} = $val if defined $val;
  }
  return %output;
}

=item B<num_cycles>

Number of cycles.

=cut

sub num_cycles {
  my $self = shift;
  if (@_) {
    $self->{NUM_CYCLES} = shift;
  }
  return $self->{NUM_CYCLES};
}

=item B<num_nod_sets>

Number of nod repeats.

=cut

sub num_nod_sets {
  my $self = shift;
  if (@_) {
    $self->{NUM_NOD_SETS} = shift;
  }
  return $self->{NUM_NOD_SETS};
}

=item B<step_time>

Step time

=cut

sub step_time {
  my $self = shift;
  if (@_) {
    $self->{STEP_TIME} = shift;
  }
  return $self->{STEP_TIME};
}

=item B<jos_mult>

.

=cut

sub jos_mult {
  my $self = shift;
  if (@_) {
    $self->{JOS_MULT} = shift;
  }
  return $self->{JOS_MULT};
}

=item B<jos_min>



=cut

sub jos_min {
  my $self = shift;
  if (@_) {
    $self->{JOS_MIN} = shift;
  }
  return $self->{JOS_MIN};
}

=item B<rows_per_ref>

The number of raster rows to complete between reference observations.

=cut

sub rows_per_ref {
  my $self = shift;
  if (@_) {
    $self->{ROWS_PER_REF} = shift;
  }
  return $self->{ROWS_PER_REF};
}

=item B<refs_per_cal>

Number of sky references between each cal observation.

=cut

sub refs_per_cal {
  my $self = shift;
  if (@_) {
    $self->{REFS_PER_CAL} = shift;
  }
  return $self->{REFS_PER_CAL};
}

=item B<n_refsamples>

Number of samples to integrate on the reference position.

=cut

sub n_refsamples {
  my $self = shift;
  if (@_) {
    $self->{N_REFSAMPLES} = shift;
  }
  return $self->{N_REFSAMPLES};
}

=item B<n_calsamples>

Number of samples to integrate for the cal observation.

=cut

sub n_calsamples {
  my $self = shift;
  if (@_) {
    $self->{N_CALSAMPLES} = shift;
  }
  return $self->{N_CALSAMPLES};
}

=item B<n_skyrefsamples>

Number of samples to use for a sky reference.

=cut

sub n_skyrefsamples {
  my $self = shift;
  if (@_) {
    $self->{N_SKYREFSAMPLES} = shift;
  }
  return $self->{N_SKYREFSAMPLES};
}

=item B<focus_steps>

Number of smu positions to stop through for a focus observation.

=cut

sub focus_steps {
  my $self = shift;
  if (@_) {
    $self->{FOCUS_STEPS} = shift;
  }
  return $self->{FOCUS_STEPS};
}

=item B<FOCS_STEP>

Size of SMU movement for each step in mm.

=cut

sub focus_step {
  my $self = shift;
  if (@_) {
    $self->{FOCUS_STEP} = shift;
  }
  return $self->{FOCUS_STEP};
}

=item B<stringify>

Create XML representation of object.

=cut

sub stringify {
  my $self = shift;
  my %args = @_;

  my $xml = '';

  $xml .= "<JOS_CONFIG>\n";

  my @tasks = $self->tasks;
  $xml .= "<tasks>".join(" ",@tasks)."</tasks>\n";

  $xml .= "<recipe NAME=\"".$self->recipe."\">\n";

  my %params = $self->parameters;
  $xml .= "<parameters \n";
  for my $p (keys %params) {
    $xml .= "            $p=\"$params{$p}\"\n"
      if defined $params{$p};
  }
  $xml .= "/>\n";
  $xml .= "</recipe>\n";


  $xml .= "</JOS_CONFIG>\n";
  return ($args{NOINDENT} ? $xml : indent_xml_string( $xml ));
}

=back

=head2 Class Methods

=over 4

=item B<getRootElementName>

Return the name of the _CONFIG element that should be the root
node of the XML tree corresponding to the JOS config.

 @names = $h->getRootElementName;

=cut

sub getRootElementName {
  return( "JOS_CONFIG" );
}

=back

=begin __PRIVATE_METHODS__

=head2 Private Methods

=over 4

=item B<_process_dom>

Using the C<_rootnode> node referring to the top of the JOS XML,
process the DOM tree and extract all the coordinate information.

 $self->_process_dom;

Populates the object with the extracted results.

=cut

sub _process_dom {
  my $self = shift;

  # Find all the header items
  my $el = $self->_rootnode;

  # Get the tasks
  my $task_list = get_pcdata( $el, "tasks" );
  my @tasks = split(/\s+/,$task_list);
  throw JAC::OCS::Config::Error::XMLEmpty("No tasks specified in JOS_CONFIG")
    unless @tasks;
  $self->tasks( @tasks );

  # get the recipe name
  my $rec = find_children( $el, "recipe", min => 1, max => 1 );
  my $rec_name = find_attr( $rec, "NAME" );
  $self->recipe( $rec_name );

  # Find the parameters
  my $par_el = find_children( $rec, "parameters", min=>1, max=>1);
  my %args = find_attr( $par_el, @PARAMS);
  $self->parameters( %args );


  return;
}

=back

=end __PRIVATE_METHODS__

=head1 XML SPECIFICATION

The JOS XML configuration specification is documented in OCS/ICD/018
with a DTD available at
http://www.jach.hawaii.edu/JACdocs/JCMT/OCS/ICD/018/jos.dtd.

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
