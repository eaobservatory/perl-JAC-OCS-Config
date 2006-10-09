package JAC::OCS::Config;

=head1 NAME

JAC::OCS::Config - Parse and write JCMT OCS Configuration XML

=head1 SYNOPSIS

  use JAC::OCS::Config;

  $cfg = new JAC::OCS::Config( XML => $xml );
  $cfg = new JAC::OCS::Config( FILE => $filename );
  $cfg = new JAC::OCS::Config( FILE => $filename, telescope => 'UKIRT' );

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
use POSIX qw/ ceil /;

use Astro::WaveBand;

use JAC::OCS::Config::Error;

use JAC::OCS::Config::ObsSummary;
use JAC::OCS::Config::TCS;
use JAC::OCS::Config::Frontend;
use JAC::OCS::Config::Instrument;
use JAC::OCS::Config::Header;
use JAC::OCS::Config::RTS;
use JAC::OCS::Config::JOS;
use JAC::OCS::Config::ACSIS;
use JAC::OCS::Config::Helper qw/ check_class_fatal /;
use JAC::OCS::Config::XMLHelper qw(
				   find_children
				   find_attr
				   indent_xml_string
				   get_pcdata_multi
				  );

# Bizarrely, inherit from a sub-class for DOM processing
use base qw/ JAC::OCS::Config::CfgBase /;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

# Overloading
use overload '""' => "_stringify_overload";

# Order in which the individual configs must be written to the file
our @CONFIGS = qw/obs_summary jos header rts frontend instrument_setup
		  tcs acsis /;


=head1 METHODS

=head2 Constructors

=over 4

=item B<new>

The constructor takes an XML representation of the config
as argument and returns a new object.

  $cfg = new JAC::OCS::Config( XML => $xml );
  $cfg = new JAC::OCS::Config( File => $xmlfile );
  $cfg = new JAC::OCS::Config( DOM => $dom );

The argument hash can refer to an XML string, an XML file or a DOM
tree. If neither is supplied no object will be instantiated. If both
C<XML> and C<File> keys exist, the C<XML> key takes priority.

A telescope can be supplied directly to the constructor if it is
known and if there is a chance that the telescope may not be specified
in the TCS_CONFIG.

Returns C<undef> if an object can not be constructed.

=cut

sub new {
  my $self = shift;
  my %args = @_;

  # extract telescope
  my $tel = $args{telescope};
  delete $args{telescope};

  # Now call base class with all the supplied options +
  # extra initialiser
  return $self->SUPER::new( %args,
                            $JAC::OCS::Config::CfgBase::INITKEY => {
								    Telescope => $tel,
                                                                   }
                          );
}

=back

=head2 Accessor Methods

=over 4

=item B<comment>

Text string to be inserted at the top of the stringified form of the
configuration in addition to any internal comment added by this module.

=cut

sub comment {
  my $self = shift;
  if (@_) {
    $self->{COMMENT} = shift;
  }
  return $self->{COMMENT};
}

=item B<tasks>

An array of task names that will be involved in the observation defined
by this configuration.

  @tasks = $cfg->tasks;

Can be used to configure the JOS. Note that the JOS is not included in
this list and also note that the tasks() method will not necessairly
contain the same values since the task list in the JOS object is not
necessairly derived from the configuration (it may just be the
settings that were read from disk).

=cut

sub tasks {
  my $self = shift;
  my @tasks;
  my %dups; # check for duplicates

  # The tasks should retain the order delievered by the subsystems but
  # we need to make sure that duplicates are removed
  # For this reason, we do not use the _task_map method.
  for my $o (@CONFIGS) {
    next if $o eq 'jos';
    if ($self->can($o) && defined $self->$o() && $self->$o->can( 'tasks' )) {
      my @new = $self->$o->tasks;
      for my $n (@new) {
	next if exists $dups{$n};
	$dups{$n} = undef;
	push(@tasks, $n);
      }
    }
  }
  return @tasks;
}

=item B<obssum>

Observation summary as an C<JAC::OCS::Config::ObsSummary> object.

=cut

sub obs_summary {
  my $self = shift;
  if (@_) {
    $self->{OBS_SUMMARY} = check_class_fatal( "JAC::OCS::Config::ObsSummary",shift);
  }
  return $self->{OBS_SUMMARY};
}

=item B<jos>

JOS configuration.

=cut

sub jos {
  my $self = shift;
  if (@_) {
    $self->{JOS_CONFIG} = check_class_fatal( "JAC::OCS::Config::JOS",shift);
  }
  return $self->{JOS_CONFIG};
}

=item B<header>

Header configuration.

=cut

sub header {
  my $self = shift;
  if (@_) {
    $self->{HEADER_CONFIG} = check_class_fatal( "JAC::OCS::Config::Header",shift);
  }
  return $self->{HEADER_CONFIG};
}


=item B<tcs>

TCS configuration.

=cut

sub tcs {
  my $self = shift;
  if (@_) {
    $self->{TCS_CONFIG} = check_class_fatal( "JAC::OCS::Config::TCS",shift);
  }
  return $self->{TCS_CONFIG};
}

=item B<acsis>

ACSIS configuration. This can be undefined if ACSIS is not part of the
observation.

  $acsis_cfg = $cfg->acsis();

=cut

sub acsis {
  my $self = shift;
  if (@_) {
    $self->{ACSIS_CONFIG} = check_class_fatal( "JAC::OCS::Config::ACSIS",shift);
  }
  return $self->{ACSIS_CONFIG};
}

=item B<instrument_setup>

Instrument configuration.

=cut

sub instrument_setup {
  my $self = shift;
  if (@_) {
    my $inst = shift;
    $self->{INSTRUMENT_CONFIG} = check_class_fatal( "JAC::OCS::Config::Instrument",
						    $inst);
    # if a frontend config exists, check to see if a name is defined
    # if it is undef, set it
    my $fe = $self->frontend;
    if (defined $fe && !defined $fe->frontend) {
      $fe->frontend( $inst->name );
    }
  }
  return $self->{INSTRUMENT_CONFIG};
}

=item B<frontend>

Frontend configuration.

=cut

sub frontend {
  my $self = shift;
  if (@_) {
    my $fe = shift;
    $self->{FRONTEND_CONFIG} = check_class_fatal( "JAC::OCS::Config::Frontend",
						  $fe);
    # if the frontend does not have a name but we do have an INSTRUMENT
    # then use that name
    # Does not verify that the receptors in INSTRUMENT are used in FRONTEND
    if (!defined $fe->frontend && defined $self->instrument_setup) {
      $fe->frontend( $self->instrument_setup->name );
    }
  }
  return $self->{FRONTEND_CONFIG};
}

=item B<rts>

RTS configuration.

=cut

sub rts {
  my $self = shift;
  if (@_) {
    $self->{RTS_CONFIG} = check_class_fatal( "JAC::OCS::Config::RTS",shift);
  }
  return $self->{RTS_CONFIG};
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

The full config is written to the output directory. Additionally,
if there are any directories in the output directory that match
task names controlled by a specific config, that directory receives
the configuration for that task.

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
  $TRANS_DIR = $self->outputdir unless defined $TRANS_DIR;

  # We need to read the directory to look for subdirs matching task names
  opendir my $dh, $TRANS_DIR or
    throw JAC::OCS::Config::Error::FatalError("Error opening OCS config output directory '$TRANS_DIR': $!");

  # Get all the dirs excluding unix hidden directories
  my @dirs = grep { -d File::Spec->catdir($TRANS_DIR,$_)
		    && $_ !~ /^\./
		  } readdir($dh);

  # Now we need to work out which directories are meant to receive
  # configurations
  my ($tmap, $invtmap) = $self->_task_map();

  # and which directories require full configurations regardless (as hash for easy access)
  my %full_configs = map { $_, undef } $self->requires_full_config;

  # loop over the directories, storing those that have a corresponding
  # key in the inverse task map
  @dirs = grep { exists $invtmap->{$_} } @dirs;;

  # Format is acsis_YYYYMMDD_HHMMSSuuuuuu.xml
  #  where uuuuuu is microseconds

  my ($sec, $mic_sec) = gettimeofday();
  my $ut = gmtime( $sec );

  # Rather than worry that the computer is so fast in looping that we might
  # reuse milli-seconds (and therefore have to check that we are not opening
  # a file that has previously been created) put micro-seconds in the filename
  my $cname = "acsis_". $ut->strftime("%Y%m%d_%H%M%S") .
    "_".sprintf("%06d",$mic_sec) .
      ".xml";

  # This name has to be associated with the relevant FITS header
  # as it can only be set when we are creating the file.
  my $header = $self->header;
  if (defined $header) {
    $header->set_ocscfg_filename( $cname );
  }


  my $storename;

  # loop over the directories, making sure that current directory is included
  for my $dir (File::Spec->curdir,@dirs) {

    my $fullname = File::Spec->catdir( $TRANS_DIR, $dir, $cname );
    print "Writing config to $fullname\n" if $self->verbose;

    # First time round, store the filename for later return
    $storename = $fullname unless defined $storename;

    # Open it [without checking to see if we are clobbering a pre-existing file]
    open my $fh, "> $fullname" or
      throw JAC::OCS::Config::Error::IOError("Error opening config output file $fullname: $!");

    # Now we use the inverse map and full config list to select specific configurations for
    # this directory
    my %strargs;
    if ($dir ne File::Spec->curdir && exists $invtmap->{$dir} && !exists $full_configs{$dir}) {
      $strargs{CONFIGS} = $invtmap->{$dir};
    }

    # horrible horrible hack because IFTASK gets flaky with large
    # XML files KLUGE ALERT
    my $has_written;
    if ($dir eq 'IFTASK') {

      # We will need a dummy Config and ACSIS object
      my $dummy = JAC::OCS::Config->new();
      my $acsis = JAC::OCS::Config::ACSIS->new();


      # store the instrument information
      $dummy->instrument_setup( $self->instrument_setup );

      # store the ACSIS object
      $dummy->acsis( $acsis );

      # we need ACSIS_IF and ACSIS_MAP
      my $this_acsis = $self->acsis();
      if (defined $this_acsis) {

	my $this_if = $this_acsis->acsis_if();
	my $this_map = $this_acsis->acsis_map();

	$acsis->acsis_if( $this_if ) if defined $this_if;
	$acsis->acsis_map( $this_map ) if defined $this_map;

	# write it
	print $fh $dummy->stringify();
	$has_written = 1;
      }
    }

    # stringify the object
    print $fh $self->stringify( %strargs ) unless $has_written;

    close ($fh) or
      throw JAC::OCS::Config::Error::IOError("Error closing config output file $fullname: $!");

    chmod $options{chmod}, $fullname
      if exists $options{chmod};

  }

  return $storename;
}

=item B<instrument>

Return the instrument (aka Front End) associated with this configuration.
Can return empty string if the Instrment has not been defined.

=cut

sub instrument {
  my $self = shift;
  my $instrument = $self->instrument_setup;
  return '' unless defined $instrument;
  return $instrument->name;
}

=item B<duration>

Estimated duration of the observation resulting from this configuration.
This must be an estimate because of uncertainties in slew time and
the possibility that a raster map may not use predictable scanning.

=cut

sub duration {
  my $self = shift;
  warn "Observation duration unknown\n" if $^W;
  return Time::Seconds->new(60);

  # Get the JOS information
  my $jos = $self->jos;
  throw JAC::OCS::Config::Error::FatalError( "Unable to determine duration since there is no JOS configuration available") unless defined $jos;

  # Get observation summary
  my $obssum = $self->obs_summary;
  throw JAC::OCS::Config::Error::FatalError( "Unable to determine duration since there is no observation summary available") unless defined $obssum;

  # Need the TCS configuration
  my $tcs = $self->tcs;
  throw JAC::OCS::Config::Error::FatalError("Unable to determine duration since there is no telescope configuration") unless defined $tcs;

  # Need the observing area (either for the number of offset positions or the
  # map area
  my $oa = $tcs->getObsArea;
  throw JAC::OCS::Config::Error::FatalError("Unable to determine duration since there is no observing area configuration") unless defined $oa;


  # Worry about SCUBA-2 at some point...
  my $map_mode = lc($obssum->mapping_mode);
  my $sw_mode  = lc($obssum->switching_mode);

  # Basic step time
  my $step = $jos->step_time;

  # This will be the number of steps per cycle to complete the observation
  my $nsteps = 0;

  # Number of times we go to a reference
  my $nrefs = 0;

  # Number of steps spent on reference
  my $nsteps_ref = 0;

  # Number of telescope nods (A->B or B->A)
  my $nnods = 0;

  # Number of SMU positions during the observations
  my $nsmu = 1;

  # Each mode needs a different calculation
  if ($map_mode eq 'raster') {

    # consistency check
    my $mode = $oa->mode;
    throw JAC::OCS::Config::Error::FatalError("Inconsistency in configuration. Raster requested but obsArea does not specify a map area (mode='$mode' not 'area')") unless $mode =~ /area/i;

    # Need to work out the number of samples in the map

    # Area of map
    my %mapdims = $oa->maparea();
    my $maparea = $mapdims{HEIGHT} * $mapdims{WIDTH};

    # Area of each "sample point"
    my %scan = $oa->scan;
    my $dx = $scan{VELOCITY} * $step;
    my $dy = $scan{DY};
    my $samparea = $dx * $dy;

    # Number of sample points
    $nsteps = $maparea / $samparea;

    # We are pessimistic here so round up.
    $nrefs = ceil( $nsteps / $jos->steps_per_ref );

    # Convert to number of reference steps
    $nsteps_ref = ceil($nrefs * $jos->n_refsamples);

  } elsif ($map_mode eq 'jiggle') {

    

  } elsif ($map_mode eq 'grid') {

    # consistency check
    my $mode = $oa->mode;
    throw JAC::OCS::Config::Error::FatalError("Inconsistency in configuration. Grid requested but obsArea does not specify offset mode (mode='$mode' not 'offsets')") unless $mode =~ /offsets/i;

    # Number of on is simply the number of offsets
    my @offsets = $oa->offsets;
    my $noffsets = scalar(@offsets);

    # Number of steps on source = JOS_MIN
    # * the number of positions
    $nsteps = $jos->jos_min * $noffsets;

    # Number of refs is the number of ons
    $nrefs = scalar(@offsets);

    # Length of each ref is same as on
    $nsteps_ref = $jos->jos_min;

  } else {
    throw JAC::OCS::Config::Error::FatalError("Unrecognized mapping mode for duration calculation: $map_mode");
  }

  # Total number of steps on+off in single cycle and smu position
  my $npercyc = $nsteps + ( $nrefs * $nsteps_ref ) + ( $nnods * $nsteps_ref );

  # if we are focus, multiply all this by the number of focus steps
  # This induces overhead
  if ($obssum->type =~ /^focus/i) {
    $nsmu = $jos->num_focus_steps;
  }

  # Get the number of cycles
  my $num_cycles = ($jos->num_cycles || 1);

  # Total number of steps in entire observation
  my $ntot = $npercyc * $num_cycles * $nsmu;

  # Approximate number of cals - needs the total number of steps
  my $ncals = $ntot / $jos->steps_per_cal;
  my $nsteps_cal = $ncals * ($jos->n_calsamples || 0);

  # Overheads
  #  - observation start and end overhead
  my $obs_overhead = 30.0;
  #  - time per telescope move to reference (there and back)
  my $tel_ref_overhead = 6.0; # seconds
  #  - time per telescope move to NOD
  my $tel_nod_overhead = 2.0;
  #  - time per SMU move
  my $smu_overhead = 2.0;
  #  - time per cal move
  my $cal_overhead = 2.0;
  #  - overhead when SETUP_SEQUENCE (need to work out how often setup_sequence runs)
  #    That number is time dependent for rasters.
  my $seq_overhead = 0.0;

  # Time per cycle, including overheads
  # Convert to an actual time
  my $duration = ( $npercyc * $step )  # on+off time
    + ( $nrefs * $tel_ref_overhead )   # number of refs
      + ( $nnods * $tel_nod_overhead); # number of nods

  # Multiply by the number of cycles
  $duration *= $num_cycles;
  $duration += ( $num_cycles * $seq_overhead );

  # Take into account SMU moves (assumes NUM_CYCLES is inside SMU loop)
  # but in general the FOCUS recipe forces NUM_CYCLES = 1
  $duration *= $nsmu;
  $duration += ( $nsmu - 1 ) * $smu_overhead;

  # Take into account cal overhead
  if ($nsteps_cal > 0) {
    $duration += ( $nsteps_cal * $step ) + ( $ncals * $cal_overhead );
  }

  # General start up / shutdown overhead
  # probably should include average slew time
  $duration += $obs_overhead;

  print "\tEstimated Duration: $duration sec\n";

  # The answer!
  return Time::Seconds->new( $duration );
}

=item B<telescope>

Return the telescope name associated with this Config.
This value is synchronized with that stored in the
C<JCMT::OCS::Config::TCS> object (if present), overwriting
the current value if specified.

 $tel = $self->telescope;

Returned as a string rather than an C<Astro::Telescope> object.
The TCS_CONFIG value takes precedence if both are defined.

=cut

sub telescope {
  my $self = shift;
  if ( @_ ) {
    my $tel = shift;
    $self->{Telescope} = shift;
    my $tcs = $self->tcs;
    $tcs->telescope( $tel ) if defined $tcs;
  }

  # return the current value
  my $tcs = $self->tcs;
  my $tcstel;
  $tcstel = $tcs->telescope if defined $tcs;
  return $tcstel if defined $tcstel;
  return $self->{Telescope};
}


=item B<projectid>

The project ID associated with this configuration. If none is defined
(e.g. if no HEADER_CONFIG available), then the method will return undef.

  $projid = $cfg->projectid;

This method does assume a specific FITS header defines the project ID.

=cut

sub projectid {
  my $self = shift;
  my $header = $self->header;

  if (defined $header) {
    my @items = $header->item( "PROJECT" );
    if (@items) {
      return $items[0]->value;
    }
  }
  return undef;
}

=item B<msbid>

The MSB ID associated with this configuration. If none is defined
(e.g. if no HEADER_CONFIG available), then the method will return undef.

  $id = $cfg->msbid;

This method does assume a specific FITS header defines the MSB ID.

=cut

sub msbid {
  my $self = shift;
  my $header = $self->header;

  if (defined $header) {
    my @items = $header->item( "MSBID" );
    if (@items) {
      return $items[0]->value;
    }
  }
  return undef;
}

=item B<obsmode>

Return a string summarizing the observing mode as defined by the
ObsSummary class. If no observation summary is stored in the configuration,
returns "UNKNOWN".

=cut

sub obsmode {
  my $self = shift;
  my $obssum = $self->obs_summary;
  return "UNKNOWN" unless defined $obssum;

  my $mode = join("_", 
		  (defined $obssum->mapping_mode ? $obssum->mapping_mode
		                                 : "unknown"),
		  (defined $obssum->switching_mode ? $obssum->switching_mode
		                                  : "unknown"),
		  (defined $obssum->type ? $obssum->type : "unknown")
		 );
  return $mode;
}

=item B<waveband>

Returns an C<Astro::WaveBand> object representing this configuration.

  $wb = $cfg->waveband;

=cut

sub waveband {
  my $self = shift;
  my $fe = $self->frontend;
  my $inst = $self->instrument;

  if (defined $fe) {
    my $rfreq = $fe->rest_frequency;
    my $wb = new Astro::WaveBand( 
				 Frequency => $rfreq,
				 Instrument => $inst,
				);

    return $wb;
  }
  return undef;
}

=item B<verify>

Attempts to verify that the configuration is complete and ready for
sending to the sequencer. Throws an exception on failure.

  $cfg->verify;

The following checks are made:

 - Does the config have a full target specification
                  (JAC::OCS::Config::Error::MissingTarget)


=cut

sub verify {
  my $self = shift;

  # get the observing mode and make sure that we need a target
  my $obs = $self->obsmode;

  if ($obs =~ /(raster|jiggle|grid)/i) {

    # Get the TCS object
    my $tcs = $self->tcs;
    if (defined $tcs) {

      # Get the target information
      my $c = $tcs->getTarget;
      throw JAC::OCS::Config::Error::MissingTarget("No science target defined in configuration") unless defined $c;

    } else {
      throw JAC::OCS::Config::Error::FatalError( "No TCS definition available in this configuration");
    }
  }

}

=item B<fixup>

Correct any run time problems with the configuration. Assumes the
modifications are for the current time.

  $cfg->fixup;

=cut

sub fixup {

}

=item B<stringify>

Convert the Science Program object into XML.

  $xml = $sp->stringify;

A hash argument can be used to control the output:

  $xml = $sp->stringify( NOINDENT => 1 );

The allowed options are:

=over 8

=item CONFIGS

A reference to an array of config objects (named after the corresponding
methods in this class) that should be included in the stringification.
If additional configurations are required (eg frontend requiring instrument)
this will be handled automatically.

=item NOINDENT

If false (the default), the XML string is returned formatted to reflect
hierarchy. If true, the string will be returned without any indenting.
This is usually used to prevent nodes within the parent from indenting
prematurely.

=back

This method is also invoked (indirectly) via a stringification overload.

  print "$sp";

The date of stringification and the version of the config object
are written to the file as comments.

If the JOS tasks method has no entries, the JOS object (if present)
will be configured with the derived task list (see the C<tasks> method
in this class).

=cut

sub stringify {
  my $self = shift;
  my %args = @_;

  my $xml = '';

  # Standard declaration plus DTD
  $xml .= '<?xml version="1.0" encoding="US-ASCII"?>' .
    '<!DOCTYPE OCS_CONFIG  SYSTEM  "/jac_sw/itsroot//ICD/001/ocs.dtd">' .
    "\n";

  $xml .= "<OCS_CONFIG>\n";

  # Insert any comment. Including a default comment.
  my $comment = "Rendered as XML on ". gmtime() . "UT using Perl module\n";
  $comment .= ref($self) . " version $VERSION Perl version $]\n";
  if ($self->comment) {
    # prepend
    $comment = $self->comment ."\n" . $comment;
  }
  $xml .= "  <!-- \n". $comment . "\n -->\n";

  # Check jos tasks
  my $jos = $self->jos;
  if (defined $jos) {
    my @tasks = $jos->tasks;
    $jos->tasks( $self->tasks ) unless @tasks;
  }

  # work out which configs we are including in the stringification
  my @configs = @CONFIGS;

  if (defined $args{CONFIGS}) {

    # now we need to make sure that the configs array is complete.
    # We first form a hash
    my %local;
    $local{$_}++ for @{ $args{CONFIGS} };

    # so loop over all the configs and make sure we include the
    # required additions. We do not loop over keys since we are
    # adding keys. Note that this is not recursive so we are not
    # resolving the case where a requirement of X on Y forces import
    # of Z. We would need some recursion for that and the current
    # OCS complexity does not warrant that
    for my $c (@{ $args{CONFIGS} }) {
      throw JAC::OCS::Config::Error::FatalError("Supplied configuration method '$c' is not supported") unless $self->can($c);
      my $object = $self->$c;
      next unless defined $object;
      my @extras = $object->dtdrequires;
      $local{$_}++ for @extras;
    }

    # and note that the order is mandated by the global @CONFIGS
    # so we have to fix that
    @configs = ();
    for my $c (@CONFIGS) {
      if (exists $local{$c}) {
	push(@configs, $c);
      }
    }
  }

  # ask each child to stringify
  for my $c (@configs) {
    my $object = $self->$c;
    next unless defined $object;
    $xml .= $object->stringify( NOINDENT => 1 );
  }

  $xml .= "</OCS_CONFIG>\n";
  return ($args{NOINDENT} ? $xml : indent_xml_string( $xml ));
}

# The overloaded stringification must be forwarded
# since the stringify() method deals with hash arguments.
sub _stringify_overload {
  return $_[0]->stringify();
}

=item B<requires_full_config>

Returns all tasks that require access to the full OCS config even if that task does not
directly interact with all subsystems.

  @tasks = $cfg->requires_full_config;

Asks each of the configurations if they have any tasks requiring full configurations.

=cut

sub requires_full_config {
  my $self = shift;
  my @full;
  for my $c (@CONFIGS) {
    # get the corresponding object
    next unless $self->can( $c );
    my $object = $self->$c;
    next unless defined $object;
    next unless $object->can( 'requires_full_config' );
    push(@full, $object->requires_full_config);
  }
  return @full;
}

=back

=head2 Class Methods

=over 4

=item B<getRootElementName>

Return the name of the _CONFIG element that should be the root
node of the XML tree corresponding to the OCS config.

 @names = $tcs->getRootElementName;

=cut

sub getRootElementName {
  return( "OCS_CONFIG" );
}

=item B<outputdir>

Default output directory for writing the ACSIS configuration. Currently
a class method rather than an instance method.

  $out = JAC::OCS::Config->outputdir();
  JAC::OCS::Config->outputdir( $newdir );

This is not to be confused with the translator default writing directory
defined in C<OMP::Translator::ACSIS>, although the translator will probably
set this value.

Should use a configuration file for this.

=cut

  {
    my $outputdir = "/jcmtdata/orac_data/ocsconfigs";
    sub outputdir {
      my $class = shift;
      if ( @_ ) {
	$outputdir = shift;
      }
      return $outputdir;
    }
  }

=item B<debug>

Enable or disable debug messages. Default is false (quiet).

  $cfg->debug( 1 );

=cut

{
  my $debug;
  sub debug {
    my $class = shift;
    if (@_) {
      $debug = shift;
    }
    return $debug;
  }
}

=item B<verbose>

Enable or disable verbose messages. Default is false (quiet).

  $cfg->verbose( 1 );

=cut

{
  my $verbose;
  sub verbose {
    my $class = shift;
    if (@_) {
      $verbose = shift;
    }
    return $verbose;
  }
}

=back

=head2 Queue Compatibility Wrappers

These methods are required to implement the JAC standard Queue interface.

=over 4

=item B<write_entry>

Write configuration to disk and return the file name.

  $file = $cfg->write_entry( $dir );

Simple wrapper around C<write_file>.

=cut

sub write_entry {
  my $self = shift;
  return $self->write_file( @_ );
}

=item B<qsummary>

Provide a simple one line summary suitable for display by the queue.
Will not include the project ID or estimated duration.

=cut

sub qsummary {
  my $self = shift;
  my $obsmode = $self->obsmode;
  my $instrument = $self->instrument;

  # target name
  my $targ = 'NONE';
  my $tcs = $self->tcs;
  if (defined $tcs) {
    my $c = $tcs->getTarget;
    $targ = $c->name if (defined $c && defined $c->name);
    $targ =~ s/\s+$//;
    $targ = "EMPTY" if !$targ; # empty string test
  }

  my $str;

  $obsmode =~ s/_/ /g;
  $str = sprintf("%-10s %-7s %s",$targ, $instrument,$obsmode);
  return $str;
}

=back

=begin __PRIVATE_METHODS__

=head2 Private Methods

=over 4

=item B<_task_map>

Returns two hashes (as references). The first is a mapping from config
method to task names, the second is the inverse mapping that maps a
task name to a particular set of configurations.

  ( $task_map, $inverse_map ) = $cfg->_task_map();

In scalar context returns the forward mapping:

  $task_map = $cfg->_task_map();

Specific task ordering is lost.

=cut

sub _task_map {
  my $self = shift;

  my %map;
  for my $c (@CONFIGS) {
    # get the corresponding object
    next unless $self->can( $c );
    my $object = $self->$c;
    next unless defined $object;
    next unless $object->can( 'tasks' );

    my @tasks;
    if ($c eq 'jos') {
      # JOS is currently a special case because the JOS tasks() method
      # returns all the tasks to be used not those required by the JOS
      @tasks = ('JOS');
    } else {
      @tasks = $object->tasks;
    }

    $map{$c} = \@tasks;
  }

  return \%map unless wantarray();

  my %inverse;
  # use a hash of hashes to build up the initial mapping
  # since order is not relevant
  for my $cfg (keys %map) {
    for my $task (@{ $map{$cfg} }) {
      $inverse{$task}{$cfg}++;
    }
  }

  # and convert the hash of hash to hash of arrays
  for my $task (keys %inverse) {
    $inverse{$task} = [ keys %{ $inverse{$task} } ]
  }

  return (\%map, \%inverse);
}

=item B<_process_dom>

Using the C<_rootnode> node referring to the top of the TCS XML,
process the DOM tree and extract all the coordinate information.

 $self->_process_dom;

Populates the object with the extracted results.

=cut

sub _process_dom {
  my $self = shift;

  my $el = $self->_rootnode;

  my $cfg = find_children( $el, "OBS_SUMMARY", min => 0, max => 1);
  $self->obs_summary( new JAC::OCS::Config::ObsSummary( DOM => $cfg) )
    if $cfg;

  $cfg = find_children( $el, "JOS_CONFIG", min => 0, max => 1);
  $self->jos( new JAC::OCS::Config::JOS( DOM => $cfg) )
    if $cfg;

  $cfg = find_children( $el, "HEADER_CONFIG", min => 0, max => 1);
  $self->header( new JAC::OCS::Config::Header( DOM => $cfg) ) if $cfg;

  # We may have a telescope hint
  my %hlp;
  my $tel = $self->telescope;
  $hlp{telescope} = $tel if defined $tel;
  $cfg = find_children( $el, "TCS_CONFIG", min => 0, max => 1);
  $self->tcs( new JAC::OCS::Config::TCS( DOM => $cfg,
					 %hlp) ) if $cfg;

  $cfg = find_children( $el, "ACSIS_CONFIG", min => 0, max => 1);
  $self->acsis( new JAC::OCS::Config::ACSIS( DOM => $cfg) ) if $cfg;

  $cfg = find_children( $el, "INSTRUMENT", min => 0, max => 1);
  $self->instrument_setup( new JAC::OCS::Config::Instrument( DOM => $cfg) )
    if $cfg;

  $cfg = find_children( $el, "FRONTEND_CONFIG", min => 0, max => 1);
  $self->frontend( new JAC::OCS::Config::Frontend( DOM => $cfg) ) if $cfg;

  $cfg = find_children( $el, "RTS_CONFIG", min => 0, max => 1);
  $self->rts( new JAC::OCS::Config::RTS( DOM => $cfg) ) if $cfg;

  return;
}

=back

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2004-2005 Particle Physics and Astronomy Research Council.
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
