package JAC::OCS::Config::Header::Item;

=head1 NAME

JAC::OCS::Config::Header::Item - Single header item

=head1 SYNOPSIS

  use JAC::OCS::Config::Header::Item;

  $i = new JAC::OCS::Config::Header::Item( KEYWORD => "INSTRUME" );


=head1 DESCRIPTION

Representation of a single FITS header item.


=cut

use 5.006;
use strict;
use Carp;
use warnings;

use vars qw/ $VERSION /;

use JAC::OCS::Config::Error;

# Overloading
use overload '""' => "_stringify_overload";

$VERSION = 1.0;

# Allowed types
my %Allowed_Types = ( 
                     FLOATING => "FLOAT",
                     FLOAT    => "FLOAT",
                     INTEGER  => "INT",
                     INT      => "INT",
                     CHARACTER=> "STRING",
                     STRING   => "STRING",
                     BLANKFIELD=> "BLANKFIELD",
                     COMMENT => "COMMENT",
                     HISTORY => "HISTORY",
                     LOGICAL => "LOGICAL",
                     BLOCK   => "BLOCK",
);

# Map the internal Source name to the allowed attributes,
# the corresponding XML output element name and a pattern suitable
# for detecting source strings in input files allowing for 
# bakwards compatibility

my %Source_Info = (
                   DRAMA => {
                             Attrs => [qw/ TASK PARAM EVENT MULT /],
                             XML   => "DRAMA",
                             Pattern => qr/^DRAMA/,
                            },
                   DERIVED => {
                               Attrs => [qw/ TASK METHOD EVENT /],
                               XML => "DERIVED",
                              },
                   SELF => {
                            Attrs => [qw/ PARAM ALT ARRAY BASE MULT/],
                            XML => "SELF",
                            },
                   RTS => {
                           Attrs => [qw/ PARAM EVENT /],
                           XML => "RTS_STATE",
                           Pattern => qr/^RTS/,
                           },
                   GLISH => {
                             Attrs => [qw/ TASK PARAM EVENT /],
                             XML => "GLISH_PARAMETER",
                             Pattern => qr/^GLISH/,
                            },
                  );

# Get all the method names relating to source attributes
my %Source_Attr_Methods = 
  map { lc($_) => undef  }
  map { @{$_->{Attrs}} } values %Source_Info;

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Constructor. The constructor takes keys that correspond
to accessor methods (case insensitive).

 $i = JAC::OCS::Config::Header::Item->new( keyword => "KEY1",
                       value => "2", is_sub_header => 1 );

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # read arguments into a hash
  my %args = @_;

  my $h = bless {}, $class;

  for my $key (keys %args) {
    my $method = lc($key);
    $h->$method( $args{$key});
  }
  return $h;
}

=back

=head2 Accessor Methods

=over 4

=item B<keyword>

FITS keyword associated with this item.

=cut

sub keyword {
  my $self = shift;
  if (@_) {
    $self->{KEYWORD} = shift;
  }
  return $self->{KEYWORD};
}

=item B<type>

FITS type associated with this item.

Allowed values are STRING/CHARACTER, LOGICAL, INT/INTEGER,
FLOAT/FLOATING, COMMENT and HISTORY.

CHARACTER will be converted to STRING, INTEGER to INT and
FLOATING to FLOAT to match the FITS definitions.

An exception is thrown if the type is not recognized.

=cut

sub type {
  my $self = shift;
  if (@_) {
    my $t = uc(shift);
    if (exists $Allowed_Types{$t}) {
      $self->{TYPE} = $Allowed_Types{$t};
    } else {
      throw JAC::OCS::Config::Error::BadArgs("Unsupported keyword type '$t'");
    }
  }
  return $self->{TYPE};
}

=item B<comment>

FITS comment associated with this item.

=cut

sub comment {
  my $self = shift;
  if (@_) {
    $self->{COMMENT} = shift;
  }
  return $self->{COMMENT};
}

=item B<value>

FITS value associated with this item.

If there is an external data source (ie if the C<source> attribute is
set), this value will probably be the default value to be used if the
external source is not contactable.

=cut

sub value {
  my $self = shift;
  if (@_) {
    $self->{VALUE} = shift;
  }
  return $self->{VALUE};
}

=item B<source>

Type of external data source that should be queried for the value.
Allowed values are "GLISH", "DRAMA", "DERIVED", "RTS" and "SELF".

=cut

sub source {
  my $self = shift;
  if (@_) {
    my $value = shift;
    if (defined $value) {
      $value = uc($value);
      JAC::OCS::Config::Error::BadArgs("Supplied source value '$value' does not match the allowed list")
          unless exists $Source_Info{$value};
    }
    $self->{SOURCE} = $value;
  }
  return $self->{SOURCE};
}

=item B<task>

Location of external data source that should be queried for the value
or, if source is DERIVED, the name of the task on which the method should
be invoked to derive the header value.

"TRANSLATOR" is a special case

=cut

sub task {
  my $self = shift;
  if (@_) {
    $self->{TASK} = shift;
  }
  return $self->{TASK};
}

=item B<param>

Parameter within external data source that should be queried for the value.

=cut

sub param {
  my $self = shift;
  if (@_) {
    $self->{PARAM} = shift;
  }
  return $self->{PARAM};
}

=item B<event>

Whether the external data source should be queried at the "START"
or "END" of the observation.

Default value is "START".

=cut

sub event {
  my $self = shift;
  if (@_) {
    $self->{EVENT} = uc(shift);
  }
  return (defined $self->{EVENT} ? $self->{EVENT} : 'START');
}

=item B<method>

If source is DERIVED, method name to use to derive the header value.

=cut

sub method {
  my $self = shift;
  if (@_) {
    $self->{METHOD} = shift;
  }
  return $self->{METHOD};
}

=item B<alt>

Alternate XPATH specification into the OCS_CONFIG to use for the header value.

Used for SELF source.

=cut

sub alt {
  my $self = shift;
  if (@_) {
    $self->{ALT} = shift;
  }
  return $self->{ALT};
}

=item B<array>

Boolean used if source is SELF to indicate whether the XML
configuration node specified by PARAM refers to an array or a scalar
value.

Default is false.

=cut

sub array {
  my $self = shift;
  if (@_) {
    $self->{ARRAY} = shift;
  }
  return $self->{ARRAY};
}

=item B<base>

Used if the source is SELF to specify a base location in the XML tree that
will be combined with the PARAM value in order to derive the true tree location.

=cut

sub base {
  my $self = shift;
  if (@_) {
    $self->{BASE} = uc(shift);
  }
  return $self->{BASE};
}

=item B<mult>

Constant multiplier to apply to the result. For example, this can be used
to convert radians to degrees.

Used for both DRAMA and SELF sources.

=cut

sub mult {
  my $self = shift;
  if (@_) {
    $self->{MULT} = shift;
  }
  return $self->{MULT};
}

=item B<is_sub_header>

Returns true if this header item has been tagged as a SUBHEADER.

=cut

sub is_sub_header {
  my $self = shift;
  if (@_) {
    my $val = shift;
    $self->{IS_SUB_HEADER} = ($val ? 1 : 0);
  }
  return $self->{IS_SUB_HEADER};
}

=back

=head1 GENERAL METHODS

=over 4

=item B<undefine>

Force the header item to refer to an undefined entry. This removes all
derived components and sets the value to the empty string.

  $item->undefine;

=cut

sub undefine {
  my $self = shift;
  $self->value( "" );
  # can effectively do this by simply removing the SOURCE value
  # but we clear everything for to prevent oddities if a source
  # is set again
  $self->unset_source;
  return;
}

=item B<unset_source>

Clear all source related information.

  $item->unset_source();

=cut

sub unset_source {
  my $self = shift;
  $self->source( undef );
  for my $m (keys %Source_Attr_Methods) {
    $self->$m( undef );
  }
  return;
}

=item B<set_source>

Convenience routine to clear the current source information and
replace it with the new supplied information.

  $item->set_source( $source, %info );

The keys in the supplied hash must match the source attributes
(TASK, PARAM, EVENT etc).

=cut

sub set_source {
  my $self = shift;
  my $source = shift;
  JAC::OCS::Config::Error::BadArgs->throw("Must define source type for set_source() method") unless defined $source;

  # clear all current values and set new source value
  $self->unset_source;
  $self->source( $source );

  # read the information from the arguments but convert the
  # keys to lower case
  my %args = @_;
  my %new_info = map { lc($_) => $args{$_} } keys %args;

  # get the attributes for this source
  # and only set information relevent to this source
  for my $attr ($self->source_attrs($source)) {
    # method name is lower case
    my $m = lc($attr);
    if (exists $new_info{$m}) {
      $self->$m($new_info{$m});
    }
  }
  return;
}

=item B<stringify>

Create XML representation of item.

=cut

sub stringify {
  my $self = shift;
  my $xml = '';

  my $head_elem = ($self->is_sub_header ? "SUB" : "" ) . "HEADER";

  $xml .= "<". $head_elem .
    " TYPE=\"" . $self->type . "\"\n";
  $xml .= "        KEYWORD=\"" . $self->keyword . "\"\n"
    unless ($self->type eq 'BLANKFIELD' || $self->type eq 'COMMENT');
  $xml .= "        COMMENT=\"" . $self->comment . "\"\n" 
    if (defined $self->comment);
  $xml .= "        VALUE=\"" . (defined $self->value ? $self->value : "") . "\" "
    unless $self->type eq 'BLANKFIELD';

  if ($self->source) {
    $xml .= ">\n";
    if ($self->source eq 'DRAMA') {

      # task and param are mandatory
      if (!defined $self->task || !defined $self->param) {
        throw JAC::OCS::Config::Error::FatalError( "One of task or param is undefined for keyword ". $self->keyword ." using DRAMA monitor");
      }

    } elsif ($self->source eq 'GLISH') {

      # task and param are mandatory
      if (!defined $self->task || !defined $self->param) {
        throw JAC::OCS::Config::Error::FatalError( "One of task or param is undefined for keyword ". $self->keyword ." using GLISH parameter");
      }

    } elsif ($self->source eq 'DERIVED') {

      # task and method are mandatory
      if (!defined $self->task || !defined $self->method) {
        throw JAC::OCS::Config::Error::FatalError( "One of task or method is undefined for keyword ". $self->keyword ." using derived header value");
      }

    } elsif ($self->source eq 'SELF') {

      # param is mandatory
      if (!defined $self->param ) {
        throw JAC::OCS::Config::Error::FatalError( "PARAM is undefined for keyword ". $self->keyword ." using internal header value");
      }

    } elsif ($self->source eq 'RTS') {

      # param is mandatory
      if (!defined $self->param ) {
        throw JAC::OCS::Config::Error::FatalError( "PARAM is undefined for keyword ". $self->keyword ." using internal header value");
      }

    } else {
      croak "Unrecognized parameter source '".$self->source;
    }
    croak "Bizarre internal error since ".$self->source.
      " does not have corresponding attribute list"
        unless exists $Source_Info{$self->source};

    $xml .= "<". $Source_Info{$self->source}{XML}. " ";
    for my $a (@{$Source_Info{$self->source}{Attrs}}) {
      my $method = lc($a);

      # special case MULT=1 since this has no useful meaning
      # but is inserted by the parser via the DTD. Some subsystems
      # get upset if it turns up for CHARACTER headers.
      next if ($a eq 'MULT' && $self->$method == 1);

      $xml .= "$a=\"" . $self->$method . '" ' if $self->$method;
    }
    $xml .= "/>\n";
    $xml .= "</$head_elem>\n";
  } else {
    $xml .= "/>\n";
  }

  return $xml;
}

# forward onto stringify method
sub _stringify_overload {
  return $_[0]->stringify();
}

=back

=head1 CLASS METHODS

=over 4

=item B<source_attrs>

Given a source string (DRAMA, RTS, DERIVED etc), return the names
of the possible attributes (TASK, PARAM etc).

 @attr = JAC::OCS::Config::Header::Item->source_attrs( "DRAMA" );

Returns empty list if the source is not recognized.

=cut

sub source_attrs {
  my $self = shift;
  my $source = shift;
  return () unless defined $source;
  $source = uc($source);

  if (exists $Source_Info{$source}) {
    return @{$Source_Info{$source}{Attrs}};
  }
  return;
}

=item B<source_types>

Returns the supported source types (DRAMA, GLISH etc). Useful
for loops.

 @sources = JAC::OCS::Config::Header::Item->source_types();

=cut

sub source_types {
  return keys %Source_Info;
}

=item B<source_pattern>

Returns a pattern match object suitable for determining whether 
a particular XML element name matches a source type.

  $qr = JAC::OCS::Config::Header::Item->source_pattern( "DRAMA" );

Returns undef if the source type is not recognized.

=cut

sub source_pattern {
  my $self = shift;
  my $source = shift;
  return unless defined $source;
  $source = uc($source);
  
  my $qr;
  if (exists $Source_Info{$source}) {
    if (exists $Source_Info{$source}{Pattern}) {
      $qr = $Source_Info{$source}{Pattern};
    } else {
      $qr = $Source_Info{$source}{XML};
      # turn into a Regexp if we have a scalar
      $qr = qr/^$qr$/;
    }
  }
  return $qr;
}

=item B<normalize_source>

Given a source string that can either be from XML or in standard internal
form, return the standard internal form.

 $norm = JAC::OCS::Config::Header::Item->normalize_source( $source );

=cut

sub normalize_source {
  my $self = shift;
  my $source = shift;
  return unless defined $source;
  $source = uc($source);

  if (exists $Source_Info{$source}) {
    # seems to already be in normalized form
    return $source;
  }

  # loop over all options, doing pattern match
  for my $s ($self->source_types) {
    my $patt = $self->source_pattern($s);
    if ($source =~ $patt) {
      return $s;
    }
  }
  return;
}

=back

=head1 SEE ALSO

L<JAC::OCS::Config::Header>.

L<Astro::FITS::Header::Item>.

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

Copyright 2004-2006 Particle Physics and Astronomy Research Council.
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

