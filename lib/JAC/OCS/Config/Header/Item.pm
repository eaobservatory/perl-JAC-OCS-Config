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

# Overloading
use overload '""' => "_stringify_overload";

$VERSION = sprintf("%d", q$Revision$ =~ /(\d+)/);

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

Allowed values are CHARACTER, LOGICAL, INTEGER, FLOATING, COMMENT and HISTORY.

=cut

sub type {
  my $self = shift;
  if (@_) {
    $self->{TYPE} = shift;
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
Allowed values are "GLISH" and "DRAMA", "DERIVED" and "SELF".

=cut

sub source {
  my $self = shift;
  if (@_) {
    my $value = shift;
    $self->{SOURCE} = (defined $value ? uc($value) : $value);
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
  # can effectively do this by simply removing the SOURCE value
  $self->source( undef );
  $self->value( "" );
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
    my @attr;
    $xml .= ">\n";
    if ($self->source eq 'DRAMA') {
      $xml .= "<DRAMA_MONITOR ";
      @attr = qw/ TASK PARAM EVENT MULT /;

      # task and param are mandatory
      if (!defined $self->task || !defined $self->param) {
        throw JAC::OCS::Config::Error::FatalError( "One of task or param is undefined for keyword ". $self->keyword ." using DRAMA monitor");
      }

    } elsif ($self->source eq 'GLISH') {
      $xml .= "<GLISH_PARAMETER ";
      @attr = qw/ TASK PARAM EVENT /;

      # task and param are mandatory
      if (!defined $self->task || !defined $self->param) {
        throw JAC::OCS::Config::Error::FatalError( "One of task or param is undefined for keyword ". $self->keyword ." using GLISH parameter");
      }

    } elsif ($self->source eq 'DERIVED') {
      $xml .= "<DERIVED ";
      @attr = qw/ TASK METHOD EVENT /;

      # task and method are mandatory
      if (!defined $self->task || !defined $self->method) {
        throw JAC::OCS::Config::Error::FatalError( "One of task or method is undefined for keyword ". $self->keyword ." using derived header value");
      }

    } elsif ($self->source eq 'SELF') {
      $xml .= "<SELF ";
      @attr = qw/ PARAM ALT ARRAY BASE /;

      # param is mandatory
      if (!defined $self->param ) {
        throw JAC::OCS::Config::Error::FatalError( "PARAM is undefined for keyword ". $self->keyword ." using internal header value");
      }

    } elsif ($self->source eq 'RTS') {

      $xml .= "<RTS_STATE ";
      @attr = qw/ PARAM EVENT /;

      # param is mandatory
      if (!defined $self->param ) {
        throw JAC::OCS::Config::Error::FatalError( "PARAM is undefined for keyword ". $self->keyword ." using internal header value");
      }

    } else {
      croak "Unrecognized parameter source '".$self->source;
    }
    for my $a (@attr) {
      my $method = lc($a);
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

