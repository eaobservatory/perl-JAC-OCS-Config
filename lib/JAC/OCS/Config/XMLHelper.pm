package JAC::OCS::Config::XMLHelper;

=head1 NAME

JAC::OCS::Config::XMLHelper - Helper functions for TCS XML parsing

=head1 SYNOPSIS

  use JAC::OCS::Config::XMLHelper;

  $pcdata = get_pcdata( $el, $elname );
  %attr = find_attr( $el, @keys );

=head1 DESCRIPTION

Generic XML helper routines, useful for all config classes.
This package is not a class.

=cut


use 5.006;
use strict;
use Carp;
use warnings;
use Exporter;
use XML::LibXML;
use Data::Dumper;

use JAC::OCS::Config::Error;
use JAC::OCS::Config::Interval;

use base qw/ Exporter /;
use vars qw/ $VERSION @EXPORT_OK /;

$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

@EXPORT_OK = qw(  get_pcdata find_attr find_children get_pcdata_multi
		  get_this_pcdata find_attr_child find_attrs_and_pcdata
		  _check_range indent_xml_string find_range interval_to_xml
		  attrs_only
	       );

=head1 FUNCTIONS

=over 4

=item B<get_this_pcdata>

Given a node object, return the first child as a string.

 $string = get_this_pcdata( $el );

The string is cleaned by removing leading and trailing whitespace.
Can return undef if there is no child.

=cut

sub get_this_pcdata {
  my $el = shift;

  my $child = $el->firstChild;

  # Return undef if the element contains no text children
  return undef unless defined $child;
  my $pcdata = $child->toString;

  # strip leading and trailing spaces
  if (defined $pcdata) {
    $pcdata =~ s/^\s+//;
    $pcdata =~ s/\s+$//;
  }

  return $pcdata;
}

=item B<get_pcdata>

Given an element and a tag name, find the element corresponding to
that tag and return the PCDATA entry from the last matching element.

 $pcdata = get_pcdata( $el, $tag );

Convenience wrapper.

Returns C<undef> if the element can not be found.

Returns C<undef> if the element can be found but does not contain
anything (eg E<lt>targetName/E<gt>).

Duplicated from C<OMP::MSB>. If this version is modified please propagate
the change back to C<OMP::MSB>.

=cut

sub get_pcdata {
  my ($el, $tag ) = @_;
  my @matches = $el->getChildrenByTagName( $tag );
  my $pcdata;
  if (@matches) {
    $pcdata = get_this_pcdata( $matches[-1] );
  }
  return $pcdata;
}

=item B<get_pcdata_multi>

Same as C<get_pcdata> but can be run with multiple tag names.

  %results = get_pcdata_multi( $el, @tags );

There is an entry in the return hash for each input tag
unless that tag could not be found.

=cut

sub get_pcdata_multi {
  my $el = shift;
  my @tags = @_;

  my %results;
  for my $t (@tags) {
    my $val = get_pcdata( $el, $t);
    $results{$t} = $val if defined $val;
  }
  return %results;
}

=item B<find_attr>

Given the element object and a list of attributes, return the attributes
as a hash.

  %attr = find_attr( $el, @keys );

Missing attributes will not be included in the returned hash.

In scalar context, the value associated with the first key in the list
is returned (even if that value is missing).

  $val = find_attr( $el, "KEY");

=cut

sub find_attr {
  my $el = shift;
  croak "Internal programming error. Supplied attribute not defined" .
    join(",",caller())
    unless defined $el;
  my @keys = @_;

  my %attr;
  for my $a (@keys) {
    my $val = $el->getAttribute( $a );
    $attr{$a} = $val if defined $val;
  }

  if (wantarray) {
    return %attr;
  } else {
    # inefficient since we find all the attributes before discarding them
    return $attr{$keys[0]};
  }

}

=item B<find_attr_child>

Find attributes associated with a child element. There must be only a 
single match for the child element name.

  %attr = find_attr_child( $parent, $child_name, @attr_names );

The end arguments and the return values match those of C<find_attr>

=cut

sub find_attr_child {
  my ($el, $tag, @keys) = @_;
  my $child = find_children( $el, $tag, min => 1, max => 1);
  return find_attr( $child, @keys );
}

=item B<find_attrs_and_pcdata>

Find both the PCDATA associated with an element and all the attributes
associated with this element.

  ($pcdata, %attributes) = find_attr_and_pcdata( $el, $tag );

Note that this function looks for a child element (see C<get_pcdata>)
and requires a single match of child element.

Unlike C<find_attr>, all attributes are returned.

=cut

sub find_attrs_and_pcdata {
  my ($el, $tag) = @_;

  my $child = find_children( $el, $tag, min=>1, max=>1);
  my $pcdata = get_this_pcdata( $child );

  # This returns XML::LibXML::Attr objects
  my @attributes = $child->attributes();

  # Extract keys and values and return
  return ($pcdata, map { $_->name, $_->value } @attributes);
}


=item B<find_children>

Return the child elements with the supplied tag name but throw an
exception if the number of children found is not the same as the number
expected.

  @children = find_children( $el, $tag, min => 0, max => 1);

If neither min nor max are specified no exception will be thrown.

In scalar context, returns the first match (useful is min and max are
both equal to 1) or undef if no matches.

If either the root element or the tag are not defined, an empty list is
returned (which may also trigger an out of range exception).

=cut

sub find_children {
  my $el = shift;
  my $tag = shift;
  my %range = @_;

  # Find the children
  my @children;
  @children = $el->getChildrenByTagName( $tag )
    if (defined $tag && defined $el);

  return _check_range( \%range, "elements named '$tag'", @children);
}

=item B<indent_xml_string>

Given an XML string, re-calculates indenting for pretty printing.

  $xml = indent_xml_string( $xml );

=cut

sub indent_xml_string {
  my $xml = shift;

  # Split into individual lines [may be expensive in memory]
  my @lines = split("\n",$xml);

  # Re-indent the XML
  $xml = '';
  my $indent = 0;
  for my $l (@lines) {
    # clean leading space unless there are no open angle brackets
    # at all
    $l =~ s/^\s+// if $l =~ /</;

    # indent to apply this time round depends on whether we
    # are opening new elements (use previous value) or closing
    # a set of elements (use correct value)
    my $this_indent = $indent;

    # See if indent has increased [simplistic approach]
    # but should be okay since I try to create xml with stand alone
    # elements rather than multiple elements per line
    if ($l =~ />/ && ($l !~ /\/>/ && $l !~ /<\// && $l !~ /->/)) {
      # Match closing angle bracket but no closing element \>
      # This allows us to deal with elements that are spread over multiple
      # lines with attributes
      $indent ++;
    } elsif ($l =~ /<\// && $l !~ /<\w/) {
      # close bracket without open bracket
      $indent --;
      $this_indent = $indent;
    }

    # prepend current indent and store in output "buffer"
    # if we just have a lone > assume we can put that on the previous line
    if ($l =~ /^\s*>\s*$/) {
      chomp($xml);
      $xml .= " >\n";
    } else {
      $xml .= ("   " x $this_indent) . $l ."\n";
    }
  }

  return $xml;
}

=item B<find_range>

Locate and parse a <range> element. Returns a C<JAC::OCS::Config::Interval>
object.

  @range = find_range( $el );
  $range = find_range( $el );

The element can either be a node that contains <range> elements,
or a <range> element itself.

In scalar context, an exception is thrown unless there is exactly one <range>
element present.

=cut

sub find_range {
  my $el = shift;

  my %options;
  if (!wantarray) {
    # Scalar context so we are expecting exactly one range
    %options = (min=>1, max => 1);
  }

  # locate the range [could be this element]
  my @range;
  if ($el->nodeName eq 'range') {
    @range = ($el);
  } else {
    @range = find_children( $el, "range", %options);
  }

  my @int;
  for my $r (@range) {
    my $units = find_attr( $r, "units");
    my $min = get_pcdata( $r, "min");
    my $max = get_pcdata( $r, "max");

    my $interval = new JAC::OCS::Config::Interval( Min => $min,
						   Max => $max,
						   Units => $units,
						 );

    push(@int, $interval);
  }

  return (wantarray ? @int : $int[0]);
}

=item B<interval_to_xml>

Convert one or more C<JAC::OCS::Config::Interval> objects to a standard
ACSIS <range> element (or multiple elements).

 $xml = interval_to_xml( @intervals );

=cut

sub interval_to_xml {
  my @in = @_;

  my $xml = "";
  for my $i (@in) {
    $xml .= "<range units=\"".$i->units."\">\n";
    $xml .= "  <min>". $i->min ."</min>\n";
    $xml .= "  <max>". $i->max ."</max>\n";
    $xml .= "</range>\n";
  }
  return $xml;
}

=item B<attrs_only>

Given an element name, and  a hash, return the XML string
that assumes a simple element with only attributes and no
PCDATA.

 $xml = attrs_only( $el, %attr);

=cut

sub attrs_only {
  my ($el, %attr) = @_;
  return "<$el ". join(" ", map { "$_=\"$attr{$_}\"" } keys %attr ) ." />\n";
}

=back

=begin __PRIVATE_FUNCTIONS__

Can be called from other Config subclasses.

=over 4

=item B<_check_range>

Given a range specifier, an error message and a list of results,
compare the list of results to the range and issue a error message
is appropriate.

  @results = _check_range( { max => 4, min => 0}, "elements", @list);

Returns the list in list context, the first element in scalar context,
else throws an exception.

=cut

sub _check_range {
  my $range = shift;
  my $errmsg = shift;
  my @input = @_;

  my %range = %$range;
  my $count = scalar(@input);

  if (exists $range->{min} && $count < $range{min} ) {
    # Too few
    if ($count == 0) {
      throw JAC::OCS::Config::Error::XMLEmpty("No $errmsg, expecting $range{min}");
    } else {
      throw JAC::OCS::Config::Error::XMLBadStructure("Too few $errmsg, expected at least $range{min} but found $count");
    }
  }

  if (exists $range{max} && $count > $range{max} ) {
    # Too many
    throw JAC::OCS::Config::Error::XMLSurfeit("Too many $errmsg, Expected no more than $range{max} but found $count");
  }

  if (wantarray) {
    return @input;
  } else {
    return $input[0];
  }

}

=back

=end __PRIVATE_FUNCTIONS__

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
