package JAC::OCS::Config;

=head1 NAME

JAC::OCS::Config - Parse and write JCMT OCS Configuration XML

=head1 SYNOPSIS

  use JAC::OCS::Config;

  $cfg = new JAC::OCS::Config( XML => $xml );
  $cfg = new JAC::OCS::Config( FILE => $filename );

  $inst = $cfg->instrument;
  $proj = $cfg->projectid;

  $coord = $cfg->centre_coords;


=head1 DESCRIPTION

Top-level module for parsing and writing JCMT OCS Configuration XML.
Also includes code for parsing a UKIRT TCS XML specification, since
both telescopes use the same PTCS. It is for this reason that the
C<JAC::> prefix is used for the namespace rather than the more specific
C<JCMT::> prefix. For UKIRT configuration see the C<UKIRT::Sequence>
module.

=cut

use 5.006;
use strict;
use warnings;
use XML::LibXML;
use Time::HiRes qw/ gettimeofday /;
use Time::Piece qw/ :override /;

use JAC::OCS::Config::TCS;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

# Overloading
use overload '""' => "stringify";


=head1 METHODS

=head2 Constructors

=over 4

=item B<new>

The constructor takes an XML representation of the config
as argument and returns a new object.

  $cfg = new JAC::OCS::Config( XML => $xml );
  $cfg = new JAC::OCS::Config( FILE => $xmlfile );

The argument hash can either refer to an XML string or
an XML file. If neither is supplied no object will be
instantiated. If both C<XML> and C<FILE> keys exist, the
C<XML> key takes priority.

Returns C<undef> if an object can not be constructed.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  throw JAC::OCS::Config::Error::BadArgs('Usage : JAC::OCS::Config->new(XML => $xml, FILE => $file)') unless @_;

  my %args = @_;

  my $xml;
  if (exists $args{XML}) {
    $xml = $args{XML};
  } elsif (exists $args{FILE}) {
    # Dont check for existence - the open will do that for me
    open my $fh, "<$args{FILE}" or return undef;
    local $/ = undef; # slurp whole file
    $xml = <$fh>;
  } else {
    warnings::warnif("Neither XML or FILE key specified to constructor");
    # Nothing of use
    return undef;
  }

  # Now convert XML to parse tree
  my $parser = new XML::LibXML;
  $parser->validation(0); # switch off validation for noew
  my $tree = eval { $parser->parse_string( $xml ) };
  if ($@) {
    throw JAC::OCS::Config::Error::SpBadStructure("Error whilst parsing configuration XML: $@\n");
  }

  # Now create Config unblessed hash
  my $cfg = {
	     Parser => $parser,
	     Tree => $tree,
	    };

  # and create the object
  bless $cfg, $class;

  # Now need to create the sub-objects
  # One per sub-system

  # First find the OCS_CONFIG root node

  # Then find all the XXX_CONFIG nodes

  # And for each one, instantiate a new Config::XXX object

  # And store in a hash

  return $cfg;
}

=back

=head2 Accessor Methods

=over 4

=item B<_tree>

Retrieves or sets the base of the document tree associated
with the science program. In general this is DOM based. The
interface does not guarantee the underlying object type
since that relies on the choice of XML parser.

=cut

sub _tree {
  my $self = shift;
  if (@_) { $self->{Tree} = shift; }
  return $self->{Tree};
}


=back

=head2 General Methods

=over 4

=item B<write_file>

Write the Config XML to disk.

  $outfile = $cfg->write_file();
  $outfile = $cfg->write_file( $dir, \%opts );

If no directory is specified, the config is written to the directory
returned by JAC::OCS::Config->outputdir(). The C<outputdir> method is
a class method, there is no scheme for overriding the default output
directory per object.

Additional options can be supplied through the optional hash (which must
be the last argument). Supported keys are:

  chmod => file protection to be used for output files. Default is to
           use the current umask.

Returns the output filename with path information for the file written in
the root directory.

Currently, the config is written to the output directory and each
sub-directory within that directory.

=cut

sub write_file {
  my $self = shift;

  # Look for hash ref as last arg and read options
  my $newopts;
  $newopts = pop() if ref($_[-1]) eq 'HASH';
  my %options = ();
  %options = (%options, %$newopts) if $newopts;

  # Now if we have anything left its a directory
  my $TRANS_DIR = shift;

  # The interface currently suggests that I write one copy into TRANS_DIR
  # itself and another copy of the XML file into each of the directories
  # found in TRANS_DIR
  $TRANS_DIR = $self->outputdir unless defined $TRANS_DIR;

  opendir my $dh, $TRANS_DIR ||
    throw JAC::OCS::Config::Error::FatalError("Error opening OCS config output directory '$TRANS_DIR': $!");

  # Get all the dirs (making sure curdir is first in the list
  # so that when things paths are formed we end up in TRANS_DIR)
  # except hidden dirs [assume unix hidden definition XXX]
  my @dirs = (File::Spec->curdir,
	      grep { -d File::Spec->catdir($TRANS_DIR,$_) && $_ !~ /^\./ } readdir($dh));

  # Format is acsis_YYYYMMDD_HHMMSSuuuuuu.xml
  #  where uuuuuu is microseconds

  my ($sec, $mic_sec) = gettimeofday();
  my $ut = gmtime( $sec );

  # Rather than worry that the computer is so fast in looping that we might
  # reuse milli-seconds (and therefore have to check that we are not opening
  # a file that has previously been created) micro-seconds in the filename
  my $cname = "acsis_". $ut->strftime("%Y%m%d_%H%M%S") .
    "_".sprintf("%06d",$mic_sec) .
      ".xml";

  my $storename;
  for my $dir (@dirs) {

    my $fullname = File::Spec->catdir( $TRANS_DIR, $dir, $cname );
    print "Writing config to $fullname\n";

    # First time round, store the filename for later return
    $storename = $fullname unless defined $storename;

    # Open it [without checking to see if we are clobbering a pre-existing file]
    open my $fh, "> $fullname" ||
      throw JAC::OCS::Config::Error::FatalError("Error opening config output file $fullname: $!");
    print $fh "$self";
    close ($fh) ||
      throw JAC::OCS::Config::Error::FatalError("Error closing config output file $fullname: $!");

    chmod $options{chmod}, $fullname
      if exists $options{chmod};

  }

  return $storename;
}

=item B<instrument>

Return the instrument (aka Front End) associated with this configuration.

=cut

sub instrument {
  warn "instrument method Not yet implemented\n";
  return "ACSIS";
}

=item B<duration>

Estimated duration of the observation resulting from this configuration.
This must be an estimate because of uncertainties in slew time and
the possibility that a raster map may not use predictable scanning.

=cut

sub duration {
  warn "Observation duration unknown\n";
  return Time::Seconds->new(10);
}

=item B<stringify>

Convert the Science Program object into XML.

  $xml = $sp->stringify;

This method is also invoked via a stringification overload.

  print "$sp";

=cut

sub stringify {
  my $self = shift;
  $self->_tree->toString;
}


=back

=head2 Class Methods

=over 4

=item B<telescope>

Return the telescope name associated with this Config.
Always returns "JCMT" if no other information is available.

=cut

sub telescope { return "JCMT" }

=back

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2004 Particle Physics and Astronomy Research Council.
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

=head1 SEE ALSO

L<SCUBA::ODF>, L<UKIRT::Sequence>

=cut

1;
