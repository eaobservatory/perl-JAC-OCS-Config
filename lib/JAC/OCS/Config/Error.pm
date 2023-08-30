package JAC::OCS::Config::Error;

=head1 NAME

JAC::OCS::Config::Error - Exception handling in an object orientated manner.

=head1 SYNOPSIS

    use JAC::OCS::Config::Error qw /:try/;
    use JAC::OCS::Config::Constants qw /:status/;

    # throw an error to be caught
    throw JAC::OCS::Config::Error::AuthenticationFail($message, OMP__AUTHFAIL);
    throw JAC::OCS::Config::Error::FatalError($message, OMP__FATAL);

    # record and then retrieve an error
    do_stuff();
    my $Error = JAC::OCS::Config::Error->prior;
    JAC::OCS::Config::Error->flush if defined $Error;

    sub do_stuff {
        record JAC::OCS::Config::Error::FatalError($message, OMP__FATAL);
    }

    # try and catch blocks
    try {
        stuff();
    }
    catch JAC::OCS::Config::Error::FatalError with {
        # its a fatal error
        my $Error = shift;
        orac_exit_normally($Error);
    }
    otherwise {
        # this block catches croaks and other dies
        my $Error = shift;
        orac_exit_normally($Error);

    };    # Don't forget the trailing semi-colon to close the catch block

=head1 DESCRIPTION

C<JAC::OCS::Config::Error> inherits from the L<Error|Error> class and more
documentation about the (many) features present in the module but
currently unused by the OMP can be found in the documentation for that
module.

As with the C<Error> package, C<JAC::OCS::Config::Error> provides two
interfaces.  Firstly it provides a procedural interface to exception
handling, and secondly C<JAC::OCS::Config::Error> is a base class for
exceptions that can either be thrown, for subsequent catch, or can
simply be recorded.

=head1 PROCEDURAL INTERFACE

C<JAC::OCS::Config::Error> exports subroutines to perform exception
handling. These will be exported if the C<:try> tag is used in the
C<use> line.

=over 4

=item try BLOCK CLAUSES

C<try> is the main subroutine called by the user. All other
subroutines exported are clauses to the try subroutine.

The BLOCK will be evaluated and, if no error is throw, try will return
the result of the block.

C<CLAUSES> are the subroutines below, which describe what to do in the
event of an error being thrown within BLOCK.

=item catch CLASS with BLOCK

This clauses will cause all errors that satisfy
C<$err-E<gt>isa(CLASS)> to be caught and handled by evaluating
C<BLOCK>.

C<BLOCK> will be passed two arguments. The first will be the error
being thrown. The second is a reference to a scalar variable. If this
variable is set by the catch block then, on return from the catch
block, try will continue processing as if the catch block was never
found.

To propagate the error the catch block may call C<$err-E<gt>throw>

If the scalar reference by the second argument is not set, and the
error is not thrown. Then the current try block will return with the
result from the catch block.

=item otherwise BLOCK

Catch I<any> error by executing the code in C<BLOCK>

When evaluated C<BLOCK> will be passed one argument, which will be the
error being processed.

Only one otherwise block may be specified per try block

=back

=head1 CLASS INTERFACE

=head2 CONSTRUCTORS

The C<JAC::OCS::Config::Error> object is implemented as a HASH. This
HASH is initialized with the arguments that are passed to it's
constructor. The elements that are used by, or are retrievable by the
C<JAC::OCS::Config::Error> class are listed below, other classes may
add to these.

    -file
    -line
    -text
    -value

If C<-file> or C<-line> are not specified in the constructor arguments
then these will be initialized with the file name and line number
where the constructor was called from.

The C<JAC::OCS::Config::Error> package remembers the last error
created, and also the last error associated with a package.

=over 4

=item throw([ARGS])

Create a new C<JAC::OCS::Config::Error> object and throw an error,
which will be caught by a surrounding C<try> block, if there is
one. Otherwise it will cause the program to exit.

C<throw> may also be called on an existing error to re-throw it.

=item with([ARGS])

Create a new C<JAC::OCS::Config::Error> object and returns it. This
is defined for syntactic sugar, eg

    die with JAC::OCS::Config::Error::FatalError($message, OMP__FATAL);

=item record([ARGS])

Create a new C<JAC::OCS::Config::Error> object and returns it. This
is defined for syntactic sugar, eg

    record JAC::OCS::Config::Error::AuthenticationFail($message, OMP__ABORT)
        and return;

=back

=head2 METHODS

=over 4

=item prior([PACKAGE])

Return the last error created, or the last error associated with
C<PACKAGE>

    my $Error = JAC::OCS::Config::Error->prior;

=back

=head2 OVERLOAD METHODS

=over 4

=item stringify

A method that converts the object into a string. By default it returns
the C<-text> argument that was passed to the constructor, appending
the line and file where the exception was generated.

=item value

A method that will return a value that can be associated with the
error. By default this method returns the C<-value> argument that was
passed to the constructor.

=back

=head1 PRE-DEFINED ERROR CLASSES

=over 4

=item B<JAC::OCS::Config::Error::Authentication>

The password provided could not be authenticated. Also encoded
in the constant C<OMP__AUTHFAIL>

=item B<JAC::OCS::Config::Error::BadArgs>

Method was called with incorrect arguments.

=item B<JAC::OCS::Config::Error::BadClass>

Method was supplied with an object of the incorrect class.

=item B<JAC::OCS::Config::Error::DirectoryNotFound>

The requested directory could not be found.

=item B<JAC::OCS::Config::Error::FatalError>

Used when we have no choice but to abort but using a non-standard
reason. It's constructor takes two arguments. The first is a text
value, the second is a numeric value, C<OMP__FATAL>. These values are
what will be returned by the overload methods.

=item B<JAC::OCS::Config::Error::IOError>

An error occurred during I/O.

=item B<JAC::OCS::Config::Error::MissingTarget>

The configuration does not specify a science target but a science
target is required.

=item B<JAC::OCS::Config::Error::NeedNextTarget>

The configuration does not specify a science target but a science
target is required and it needs to be the actual coordinate
of the science target and not a nearby object.

=item B<JAC::OCS::Config::Error::XMLBadStructure>

The configuration XML was not valid.

=item B<JAC::OCS::Config::Error::XMLConfigMissing>

An element required for the Config constructor object
(e.g TCS_CONFIG) was meant to be present but could not be found.

=item B<JAC::OCS::Config::Error::XMLEmpty>

A requested element could not be found in the XML.

=item B<JAC::OCS::Config::Error::XMLSurfeit>

Too many relevant configs were found in the DOM tree.

=back

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Alasdair Allan E<lt>aa@astro.ex.ac.ukE<gt>

=head1 COPYRIGHT

Copyright (C) 2001-2005 Particle Physics and Astronomy Research Council.
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

use Error;
use warnings;
use strict;

our $VERSION = "1.01";

# flush method added to the base class
use base qw/Error::Simple/;

package JAC::OCS::Config::Error::Authentication;
use base qw/JAC::OCS::Config::Error/;

package JAC::OCS::Config::Error::BadArgs;
use base qw/JAC::OCS::Config::Error/;

package JAC::OCS::Config::Error::BadClass;
use base qw/JAC::OCS::Config::Error/;

package JAC::OCS::Config::Error::DirectoryNotFound;
use base qw/JAC::OCS::Config::Error/;

package JAC::OCS::Config::Error::FatalError;
use base qw/JAC::OCS::Config::Error/;

package JAC::OCS::Config::Error::IOError;
use base qw/JAC::OCS::Config::Error/;

package JAC::OCS::Config::Error::MissingTarget;
use base qw/JAC::OCS::Config::Error/;

package JAC::OCS::Config::Error::NeedNextTarget;
use base qw/JAC::OCS::Config::Error/;

package JAC::OCS::Config::Error::XMLBadStructure;
use base qw/JAC::OCS::Config::Error/;

package JAC::OCS::Config::Error::XMLConfigMissing;
use base qw/JAC::OCS::Config::Error/;

package JAC::OCS::Config::Error::XMLEmpty;
use base qw/JAC::OCS::Config::Error/;

package JAC::OCS::Config::Error::XMLSurfeit;
use base qw/JAC::OCS::Config::Error/;

1;
