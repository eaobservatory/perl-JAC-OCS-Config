package JAC::OCS::Config::Helper;

=head1 NAME

JAC::OCS::Config::Helper - General helper functions for Config classes

=head1 SYNOPSIS

  use JAC::OCS::Config::Helper qw/ check_class /;

  @ok = check_class( $class, @objects );


=head1 DESCRIPTION

General helper functions that are used by more than one Config class.

=cut

use 5.006;
use strict;
use Carp;
use warnings;
use Exporter;

use JAC::OCS::Config::Error qw/ :try /;

use base qw/ Exporter /;
use vars qw/ $VERSION @EXPORT_OK /;

$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

@EXPORT_OK = qw(
		check_class
		check_class_fatal
	       );

=head1 FUNCTIONS

=over 4

=item B<check_class>

Given a class name, and some objects, check that each object is one of
those classes. Returns all the valid input arguments, allowing direct
assignment of return value

 @ok = check_class( "Astro", @input );

Note that the number of return arguments can be smaller than the number
of input arguments.

In scalar context returns the first valid argument.

=cut

sub check_class {
  my $class = shift;

  # Now check inheritance
  my @output = grep { UNIVERSAL::isa($_, $class) } @_;
  return (wantarray ? @output : $output[0] );
}

=item B<check_class_fatal>

Identical to C<check_class> except that a BadClass exception is thrown if any
of the supplied arguments are incorrect.

=cut


sub check_class_fatal {
  # run check_class with the supplied arguments
  my @output = check_class( @_ );

  # compare the number of returned arguments with the number supplied
  # (taking into account the extra input argument
  if (@output != (scalar(@_) - 1 ) ) {
    # get the parent function
    my @c = caller(1);
    my $n_in = scalar(@_) - 1;
    my $lost = $n_in - scalar(@output);

    my $msg;
    if ($n_in == 1) {
      $msg = "The input argument ";
    } else {
      $msg = "$lost out of $n_in arguments ";
    }
    $msg .= "to '$c[3]' not of class '$_[0]'";

    throw JAC::OCS::Config::Error::BadClass( $msg );
  }
  return (wantarray ? @output : $output[0] );
}

=back


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


