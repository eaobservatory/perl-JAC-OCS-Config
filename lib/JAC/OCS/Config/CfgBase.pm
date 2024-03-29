package JAC::OCS::Config::CfgBase;

=head1 NAME

JAC::OCS::Config::CfgBase - Base class for config sub-systems

=head1 SYNOPSIS

    use JAC::OCS::Config::CfgBase;

=head1 DESCRIPTION

This class provides a base implementation for all the Config
sub-systems that are configured using XML. It is used by all the OCS
subsystems (everything that has a C<_CONFIG> element within an
C<OCS_CONFIG> root element).

=cut

use strict;
use warnings;
use XML::LibXML qw/:libxml/;
use File::Spec;
use File::Basename qw/dirname/;
use Cwd qw/getcwd/;

use JAC::OCS::Config::Error qw/:try/;
use JAC::OCS::Config::Version;

# Overloading
use overload '""' => "_stringify_overload";

# This is the key that sub-classes should use if they want
# to supply additional init values to the constructor
our $INITKEY = '__init';

our $VERSION = "1.01";

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new sub-system configuration object. An object can be created from
a file name on disk, a chunk of XML in a string or a previously created
DOM tree generated by C<XML::LibXML> (i.e. A C<XML::LibXML::Element>).

    $cfg = new JAC::OCS::Config::TCS(File => $file);
    $cfg = new JAC::OCS::Config::TCS(EntityFile => $file);
    $cfg = new JAC::OCS::Config::TCS(EntityFile => $file, Wrapper => 'TCS_CONFIG');
    $cfg = new JAC::OCS::Config::TCS(XML => $xml);
    $cfg = new JAC::OCS::Config::TCS(DOM => $dom);

The XML must contain an C<XXX_CONFIG> element corresponding to the
subclass.

Other optional keys are:

=over 4

=item validation

Boolean indicating whether to enable validation in XML
parse. Important if you are relying on default values
for attributes.

=back

A special key (C<$JAC::OCS::Config::CfgBase::INITKEY>) can be supplied
by a subclass to provide additional, sub-system specific
initialisation keys. It should be a reference to a hash.

The method will throw a BadArgs exception if unrecognised arguments
are found. It is possible to instantiate a blank object but it is the
callers responsibility to populate it.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    # Read the arguments
    my %args = @_;

    my %extra;
    %extra = %{$args{$INITKEY}}
        if exists $args{$INITKEY};
    delete $args{$INITKEY};

    # Create the object
    my $cfg = bless {
        Parser => undef,
        Tree => undef,
        ConfigNode => undef,
        FileName => undef,
        DTDValidation => 1,
        IsDOMValid => {},
        %extra
    }, $class;

    # Store options
    for my $key (qw/validation/) {
        my $method = "_" . $key;
        if (exists $args{$key}) {
            $cfg->$method($args{$key});
            delete $args{$key};
        }
    }

    # process the arguments
    if (exists $args{DOM} && defined $args{DOM}) {
        $cfg->_import_dom($args{DOM});
    }
    elsif (exists $args{XML} && defined $args{XML}) {
        $cfg->_import_xml_string($args{XML});
    }
    elsif (exists $args{File} && defined $args{File}) {
        $cfg->_import_xml_file($args{File});
    }
    elsif (exists $args{EntityFile} && defined $args{EntityFile}) {
        $cfg->_import_xml_entity_file($args{EntityFile}, $args{Wrapper});
    }
    elsif (%args) {
        throw JAC::OCS::Config::Error::BadArgs(
            "Arguments supplied ["
            . join(",", keys %args)
            . "] to $class constructor but not recognized");
    }

    return $cfg;
}

=back

=head2 Accessor Methods

=over 4

=item B<filename>

Name of XML file used to construct the object (if any).

=cut

sub filename {
    my $self = shift;
    if (@_) {
        $self->{FileName} = shift;
    }
    return $self->{FileName};
}

=item B<cfg_date>

If the config XML has been read from a file, this is the modification
date of the file as epoch seconds.

    $date = $map->cfg_date();

Read only.

=cut

sub cfg_date {
    my $self = shift;
    if (@_) {
        $self->{CfgDate} = shift;
    }
    return $self->{CfgDate};
}


=item B<isDOMValid>

Hash indicating whether any given element under the root _CONFIG
element is valid in the DOM tree. All are set to true during the
initial parse but can be invalidated subsequently by using accessor
methods to change content. Obviously, if no DOM was used for constructing
the object all values are false.

    $cfg->isDOMValid(TCS_CONFIG => 1);
    $isok = $cfg->isDOMValid("SECONDARY");

The keys are assumed to match element names and are used during
object stringification.

=cut

sub isDOMValid {
    my $self = shift;

    # Always false if no DOM tree exists
    return undef unless $self->_rootnode;

    if (@_) {
        # Single argument is a state query
        if (scalar(@_) == 1) {
            my $key = shift;

            # make sure we do not make the hash bigger if the key is unrecognised
            return undef unless exists $self->{DOMValid}->{$key};
            return $self->{IsDOMValid}->{$key};
        }
        else {
            # more than one argument, hash arg
            my %args = @_;
            for my $a (keys %args) {
                # Copy in booleans regardless of real values
                $self->{IsDOMValid}->{$a} = ($args{$a} ? 1 : undef);
            }
        }
    }

    # No action if no args since I do not really want to return
    # a reference to the underlying hash.
}

=item B<_validation>

Indicate whether the parser should use DTD validation or not. Default
is to enable validation.

=cut

sub _validation {
    my $self = shift;
    if (@_) {
        $self->{DTDValidation} = shift;
    }
    return $self->{DTDValidation};
}

=item B<_parser>

The C<XML::LibXML> object associated with the tree. Not defined
if a DOM was used to instantiate the object.

=cut

sub _parser {
    my $self = shift;
    if (@_) {
        $self->{Parser} = shift;
    }
    return $self->{Parser};
}

=item B<_tree>

Parse tree associated with the XML used to instantiate the
object. Does not necessarily refer to the beginning of the
configuration XML segment of the parse tree (will normally refer to
the beginning of whatever XML was passed into the constructor).

=cut

sub _tree {
    my $self = shift;
    if (@_) {
        $self->{Tree} = shift;
    }
    return $self->{Tree};
}

=item B<_rootnode>

Node in the parse tree corresponding to the start of the configuration
XML (the XXX_CONFIG element).

=cut

sub _rootnode {
    my $self = shift;
    if (@_) {
        $self->{ConfigNode} = shift;
    }
    return $self->{ConfigNode};
}

=back

=head2 General Methods

=over 4

=item B<stringify>

Convert the object to XML. Ignores all arguments (although the specific
child implementations will support hash arguments) and simply stringifies
the root node.

Indirectly called by the stringification operator.

=cut

sub stringify {
    my $self = shift;

    # Presumably need to force synchronization of content with DOM
    # if we are doing this seriously.

    # Get root note
    my $root = $self->_rootnode;

    # default empty string
    my $string = "";

    # insert a comment if we have a root node
    if (defined $root) {
        # Get comment string
        my $comstring = $self->_introductory_xml();

        # need to clean it up
        $comstring =~ s/<!--//m;
        $comstring =~ s/-->//m;

        # Create comment node
        my $com = XML::LibXML::Comment->new($comstring);
        my $nl = XML::LibXML::Text->new("\n");

        # Get first child
        my $fc = $root->firstChild;

        my $already_have = 0;
        if ($fc->nodeType() eq XML_COMMENT_NODE) {
            $already_have = 1;
        }
        elsif ($fc->nodeType() eq XML_TEXT_NODE) {
            my $sibling = $fc->nextSibling();
            if ((defined $sibling) and $sibling->nodeType() eq XML_COMMENT_NODE) {
                $already_have = 1;
            }
        }

        # and insert the comment if we don't already have one
        unless ($already_have) {
            $root->insertBefore($nl, $fc);
            $root->insertBefore($com, $fc);
        }

        # and stringify the resultant node
        $string = $root->toString;

        unless ($already_have) {
            # Remove the comment again
            $com->unbindNode;
            $nl->unbindNode;
        }
    }

    return $string;
}

# forward onto stringify method
sub _stringify_overload {
    return $_[0]->stringify();
}

=item B<requires_full_config>

Returns the name of any tasks that require access to the full OCS configuration
even if not all tasks are required by the subsystem.

    @tasks = $cfg->requires_full_config();


Always returns empty list in the base class.

=cut

sub requires_full_config {
    my $self = shift;

    # Base class always returns false
    return ();
}

=back

=head2 Class Methods

=over 4

=item B<dtdrequires>

Returns the names of any associated configurations required for this
configuration to be used in a full OCS_CONFIG.

    @requires = $cfg->dtdrequires();

Can return an empty list if the configuration does not need any additional
information to be compliant.

Mainly intended for use by top level configurations where the strings
in the list must match method names in the C<JAC::OCS::Config> class.

=cut

sub dtdrequires {
    return ();
}

=back

=begin __PRIVATE_METHODS__

=head2 Private Methods

=over 4

=item B<_read_xml_from_file>

Utility routine for reading a file into a single string and returning it.

    $xml = $self->_read_xml_from_file($filename);

=cut

sub _read_xml_from_file {
    my $self = shift;
    my $file = shift;

    open my $fh, "< $file"
        or throw JAC::OCS::Config::Error::IOError(
        "Error opening XML file $file : $!");

    local $/ = undef;
    my $xml = <$fh>;

    close($fh)
        or throw JAC::OCS::Config::Error::IOError(
        "Error closing XML file $file : $!");

    # Look up the modification date on the file
    my @stat = stat($file);
    $self->cfg_date($stat[9]);

    return $xml;
}

=item B<_import_xml_file>

Open a file and read the contents into the object. Called from the object
constructor. Calls C<_import_xml_string>.

    $self->_import_xml_file($filename);

Entities are read from this file relative to the location of the file
(as opposed to relative to the current working directory).

=cut

sub _import_xml_file {
    my $self = shift;
    my $file = shift;

    # This method does not read the entities directly.
    # They will be read by the parser but we have to make sure that
    # we are in the correct directory to allow the parser to do a relative
    # read

    # read the file off disk
    # we do not use the builtin file parser since we want to reduce the
    # code that deals with validation parameters and DOM importing
    my $xml = $self->_read_xml_from_file($file);

    # We need to chdir to the path
    my $cdinfo = $self->_cdtoxml($file);

    # Run this in a try block so we can chdir back again
    my $E;
    try {
        $self->_import_xml_string($xml);
    }
    otherwise {
        $E = shift;
    };

    # get back to the current directory before throwing the exception
    $self->_cdfromxml($cdinfo);

    if ($E) {
        if (ref($E) && $E->can("throw")) {
            $E->throw;
        }
        else {
            # Convert to an exception if we are not a standard execption
            JAC::OCS::Config::Error::XMLBadStructure->throw("$E");
        }
    }

    $self->filename($file);
}

=item B<_import_xml_entity_file>

Import the name of an XML file that contains a chunk of XML (usually a .ent suffix) rather than a fully fledged XML document. For this to work, the XML
is read from disk and an enclosing wrapper element is supplied (this can be
provided by the optional second argument to this method, else one is made up).

    $self->_import_xml_entity_file($entity_file);
    $self->_import_xml_entity_file($entity_file, $wrapper);

The wrapper is useful if you have a chunk of XML that provides two
elements of interest but not a full specification. The parents
getRootElementName would be an obvious choice.

=cut

sub _import_xml_entity_file {
    my $self = shift;
    my $file = shift;
    my $wrapper = (shift || 'dummyWrapperElement');
    my $xml = $self->_read_xml_from_file($file);

    # We need the XInclude namespace to allow this entity to use XInclude
    $xml = "<$wrapper xmlns:xi=\"http://www.w3.org/2001/XInclude\">\n$xml\n</$wrapper>\n";

    # See _import_xml_file
    # We need to chdir to the path
    my $cdinfo = $self->_cdtoxml($file);

    # Run this in a try block so we can chdir back again
    my $E;
    try {
        $self->_import_xml_string($xml);
    }
    otherwise {
        $E = shift;
    };

    # get back to the current directory before throwing the exception
    $self->_cdfromxml($cdinfo);

    if ($E) {
        if (ref($E) && $E->can("throw")) {
            $E->throw;
        }
        else {
            # Convert to an exception if we are not a standard execption
            JAC::OCS::Config::Error::XMLBadStructure->throw("$E");
        }
    }

    $self->filename($file);
}

=item B<_import_xml_string>

Import a string containing the subsystem XML into the object.
Called from the object constructor or from C<_import_xml_file>.

    $self->_import_xml_string($string);

=cut

sub _import_xml_string {
    my $self = shift;
    my $xml = shift;

    # create new parser
    my $parser = new XML::LibXML;
    $parser->validation($self->_validation);
    $parser->expand_xinclude(1);
    $self->_parser($parser);

    # Allow the parser to fail
    my $tree = $parser->parse_string($xml);

    $self->_import_dom($tree);
}

=item B<_import_dom>

Import the DOM (created by C<XML::LibXML>) into the object.
Throws an exception if Config information can not be found in the
tree.

    $self->_import_dom($tree);

Uses the getRootElementName method (in the subclass) to determine which
CONFIG elements are actually useful (and sets the first matching node
into the _rootnode attribute). Calls subclasses _process_dom method.

Note that if the first element name matches, the second name will not
be used.

=cut

sub _import_dom {
    my $self = shift;
    my $tree = shift;

    # Get the root element
    my @elements = $self->getRootElementName();

    # Look for each element name, one at a time
    my @nodes;
    for my $elname (@elements) {
        # If we are not a document object and the root node name is exactly
        # what we want already, just use it.
        if (!$tree->isa("XML::LibXML::Document") && $tree->nodeName eq $elname) {
            @nodes = ($tree);
            last;
        }

        # Now look for the relevant config information
        @nodes = $tree->findnodes(".//$elname");

        throw JAC::OCS::Config::Error::XMLSurfeit(
            "DOM contains multiple configurations named '$elname'")
            if scalar(@nodes) > 1;

        # Jump out the loop if we have found something
        last if @nodes;
    }

    throw JAC::OCS::Config::Error::XMLConfigMissing(
        "DOM contains no configurations named " . join(" or ", @elements))
        if !scalar(@nodes);

    # found some configuration XML. Store it
    $self->_tree($tree);
    $self->_rootnode($nodes[0]);
    $self->_process_dom();
}

=item B<_process_dom>

Dummy routine for processing a DOM tree. Does nothing and so is only
useful if you intend to simply read the XML and write it out without
modification or content extraction.

=cut

sub _process_dom {
}

=item B<_introductory_xml>

Returns an XML snippet to be included at the top of the stringified
XML (if requested by the specific subclass). Usually consists of a class
name and version number.

    $text = $self->_introductory_xml();

=cut

sub _introductory_xml {
    my $self = shift;

    # Get the repository version information
    my $repover = JAC::OCS::Config::Version::version();

    # Use the VERSION method inherited from UNIVERSAL
    my $version = $self->VERSION;

    my $xml = "<!--\nCreated using class " . ref($self) . " V$version\n($repover)\n";

    # for debugging of translations, we really need to know the
    # inheritance version numbers. This is hairy code using symbolic
    # references so we have to limit the scope of strict relaxation.
    {
        no strict "refs";
        my @isa = @{ref($self) . "::ISA"};

        for my $b (@isa) {
            $xml .= "+ which inherits from class $b V" . ${$b . "::VERSION"} . "\n";
        }
    }

    # Filename and version number if available
    my $cfg_d = $self->cfg_date;
    my $file = $self->filename;
    if (defined $file) {
        $xml .= "\n";
        $xml .= "Configuration read from file '$file'\n";
        $xml .= "+ configuration file last modified on " . gmtime($cfg_d) . " UT\n"
            if defined $cfg_d;
    }

    # close the comment
    $xml .= "-->\n";

    return $xml;
}

=item B<_cdtoxml>

Change to the xml directory so that relative path entities can be read
correctly.

    $cdinfo = $cfg->_cdtoxml($xmlfile);

See also C<_cdfromxml> to get back again.
Returns information that can be passed to C<_cdfromxml>.

=cut

sub _cdtoxml {
    my $self = shift;
    my $file = shift;

    # Rather than get the current working directory simply to return
    # to it, we open the current directory and will chdir back to it later.
    # Do nothing if dirname returns the current directory
    my $dirname = dirname($file);

    my $currdir;
    if (defined $dirname && $dirname ne File::Spec->curdir) {
        # Modern perls can use fchdir
        if ($] >= 5.008008) {
            opendir($currdir, File::Spec->curdir)
                or throw JAC::OCS::Config::Error::FatalError(
                "Error opening current directory");
        }
        else {
            $currdir = getcwd;
        }

        # Change to the directory
        my $status = chdir($dirname);
        throw JAC::OCS::Config::Error::FatalError(
            "Could not chdir to XML file location [$dirname]")
            unless $status;
    }

    return [$currdir];
}

=item B<_cdfromxml>

Change directory back to the original location from the XML directory.
Should be done after parsing the xml.

    $cfg->_cdfromxml($cdinfo);

Takes as argument the return value from C<_cdtoxml>.

=cut

sub _cdfromxml {
    my $self = shift;
    my $cdinfo = shift;
    my $currdir = $cdinfo->[0];

    # get back to the current directory before throwing the exception
    if (defined $currdir) {
        chdir($currdir)
            or throw JAC::OCS::Config::Error::FatalError(
            "Could not chdir back to old working directory [$currdir]!");
        $cdinfo->[0] = undef;
    }

    return;
}

=back

=end __PRIVATE_METHODS__

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

Copyright 2002-2005 Particle Physics and Astronomy Research Council.
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
