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
use IO::Tee;
use List::Util qw/ max min /;

use Astro::WaveBand;
use JCMT::SMU::Jiggle;
use JCMT::TCS::Pong;

use JAC::OCS::Config::Error;
use JAC::OCS::Config::Version;

use JAC::OCS::Config::ObsSummary;
use JAC::OCS::Config::TCS;
use JAC::OCS::Config::Frontend;
use JAC::OCS::Config::SCUBA2;
use JAC::OCS::Config::Instrument;
use JAC::OCS::Config::Header;
use JAC::OCS::Config::RTS;
use JAC::OCS::Config::POL;
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

use vars qw/ $VERSION $DEBUG /;
$VERSION = "1.05";

# Debug messages
$DEBUG = 0;

# Overloading
use overload '""' => "_stringify_overload";

# Order in which the individual configs must be written to the file
our @CONFIGS = qw/obs_summary jos header rts scuba2 frontend pol
                  instrument_setup tcs acsis /;


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

Throws L<JAC::OCS::Config::Error> exception if an object can not be
constructed.

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
necessarily derived from the configuration (it may just be the
settings that were read from disk).

=cut

sub tasks {
  my $self = shift;
  my @tasks;
  my %dups;                     # check for duplicates

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

=item B<obs_summary>

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
    throw JAC::OCS::Config::Error::FatalError("SCUBA-2 configuration already present")
      if defined $self->scuba2();
    $self->{ACSIS_CONFIG} = check_class_fatal( "JAC::OCS::Config::ACSIS",shift);
  }
  return $self->{ACSIS_CONFIG};
}

=item B<scuba2>

SCUBA-2 configuration. Can not be present if ACSIS is also defined.

  $scuba2_config = $cfg->scuba2;

=cut

sub scuba2 {
  my $self = shift;
  if (@_) {
    throw JAC::OCS::Config::Error::FatalError("ACSIS configuration already present")
      if defined $self->acsis();
    throw JAC::OCS::Config::Error::FatalError("Heterodyne frontend configuration already present")
      if defined $self->frontend();
    $self->{SCUBA2_CONFIG} = check_class_fatal( "JAC::OCS::Config::SCUBA2",
                                                shift);
  }
  return $self->{SCUBA2_CONFIG};
}

=item B<pol>

Polarimeter configuration. This can be undefined if the polarimeter is
not part of the observation.

  $acsis_cfg = $cfg->pol();

=cut

sub pol {
  my $self = shift;
  if (@_) {
    $self->{POL_CONFIG} = check_class_fatal( "JAC::OCS::Config::POL",shift);
  }
  return $self->{POL_CONFIG};
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
    throw JAC::OCS::Config::Error::FatalError("SCUBA-2 configuration already present")
      if defined $self->scuba2();
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

  # Reading the directory can take a long time. Since we know that the
  # number of possible directory names is small we simply see if those
  # directories are present.

  # Get the possible list of directories that are meant to receive
  # configurations
  my ($tmap, $invtmap) = $self->_task_map();

  my @dirs = grep { -d File::Spec->catdir($TRANS_DIR,$_) } keys %$invtmap; 

  # Directories which require full configurations regardless (as hash for easy access)
  my %full_configs = map { $_, undef } $self->requires_full_config;

  # Format is backend_YYYYMMDD_HHMMSSuuuuuu.xml
  #  where uuuuuu is microseconds

  my ($sec, $mic_sec) = gettimeofday();
  my $ut = gmtime( $sec );

  # get backend
  my $backend = $self->backend;
  $backend = "unknown" unless defined $backend;

  # Rather than worry that the computer is so fast in looping that we might
  # reuse milli-seconds (and therefore have to check that we are not opening
  # a file that has previously been created) put micro-seconds in the filename
  my $cname = $backend . "_". $ut->strftime("%Y%m%d_%H%M%S") .
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
    print {$self->outhdl} "Writing config to $fullname\n" if $self->verbose;

    # First time round, store the filename for later return
    $storename = $fullname unless defined $storename;

    # Open it [without checking to see if we are clobbering a pre-existing file]
    open(my $fh, "> $fullname") or
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

=item B<is_cont>

Returns true if this is represents a continuum observation, false (0) if it
is heterodyne. Returns undef if there is not enough information to determine
the configuration mode.

   $iscont = $cfg->is_cont( );

JCMT specific.

=cut

sub is_cont {
  my $self = shift;
  if (defined $self->scuba2()) {
    return 1;
  } elsif (defined $self->acsis() || defined $self->frontend()) {
    return 0;
  }
  return undef;
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

=item B<instrument_serial>

Return the instrument (aka Front End) serial name associated with this
configuration.  This is usually the common name that most people know
of as the front end (as opposed to the task name returned by the
"instrument" method).  Can return empty string if the Instrment has
not been defined.

=cut

sub instrument_serial {
  my $self = shift;
  my $instrument = $self->instrument_setup;
  return '' unless defined $instrument;
  return $instrument->serial;
}

=item B<duration>

Estimated duration of the observation resulting from this configuration.
This must be an estimate because of uncertainties in slew time and
the possibility that a scan map may not use predictable scanning.

  $duration = $Cfg->duration();

Returns a Time::Seconds object.

=cut

sub duration {
  my $self = shift;

  # switch on instrument.
  if (defined $self->acsis) {
    return $self->duration_acsis();
  } elsif (defined $self->scuba2) {
    return $self->duration_scuba2();
  } else {
    warn "Unable to determine instrument configuration for duration calculation";
  }
  return Time::Seconds->new(0);
}

=item B<duration_scuba2>

SCUBA-2 specific calculation of observing duration. Currently separate
from ACSIS since commonality of calcualations is unknown and observing modes
are somewhat different.

  $dur = $cfg->duration_scuba2();

=cut

sub duration_scuba2 {
  my $self = shift;

  # Get the JOS information
  my $jos = $self->jos;
  throw JAC::OCS::Config::Error::FatalError( "Unable to determine duration since there is no JOS configuration available") unless defined $jos;

  # Get observation summary
  my $obssum = $self->obs_summary;
  throw JAC::OCS::Config::Error::FatalError( "Unable to determine duration since there is no observation summary available") unless defined $obssum;

  # get the base mapping modes
  my $map_mode = lc($obssum->mapping_mode);
  my $obs_type = lc($obssum->type);

  # Get the effective step time. This is to compensate for the requested step time
  # not being the same as the step time you actually get. We only adjust the 5ms step
  # time.
  my $eff_step_time = $jos->step_time;
  if ($eff_step_time < 0.0051) {
    $eff_step_time *= 1.16;
  }

  # if this is a noise/flatfield observation then we do not need a tcs
  my $tcs;
  my $oa;

  if ($obs_type ne "flatfield" && $obs_type ne 'array_tests' &&
     $obs_type ne 'noise' && $obs_type ne 'setup') {

    # Need the TCS configuration
    $tcs = $self->tcs;
    throw JAC::OCS::Config::Error::FatalError("Unable to determine duration since there is no telescope configuration") unless defined $tcs;

    # Need the observing area (either for the number of offset positions or the
    # map area
    $oa = $tcs->getObsArea;
    throw JAC::OCS::Config::Error::FatalError("Unable to determine duration since there is no observing area configuration") unless defined $oa;
  }

  # Steps between darks
  my $steps_btwn_darks = $jos->steps_btwn_dark();

  # Things that can happen
  my $ndarks = 0;
  my $nseq = 1;
  my $time_per_seq = 0;

  if ($obs_type eq 'skydip') {

    my @el = $oa->skydip;

    if ($map_mode eq 'scan') {

      $nseq = 1;
      $ndarks = 1;
      
      # elevation range
      my $delta_el = abs( $el[-1]->degrees - $el[0]->degrees );

      # velocity in degrees
      my $scanvel = $oa->skydip_velocity() / 3600;

      # time taken to scan
      $time_per_seq = $delta_el / $scanvel;

      # convert to steps
      $time_per_seq = $time_per_seq / $eff_step_time;

    } elsif ($map_mode eq 'stare') {
      $time_per_seq = $jos->jos_min();
      $nseq = @el;
      $ndarks = $nseq;

    } else {
      JAC::OCS::Config::Error::FatalError->throw( "Unknown map mode for SCUBA-2 skydip: '$map_mode'");
    }

  } elsif ($obs_type eq 'flatfield') {

    # no darks
    $ndarks = 0;

    # time per sequence is in calsamples
    $time_per_seq = $jos->n_calsamples;

    # number of sequences is twice the number of steps + 1 at the end
    $nseq = ($jos->num_cycles() * 2) + 1;

  } elsif ($obs_type eq 'noise') {

    # number of sequences 
    $nseq = $jos->num_cycles;

    # integration time per non-dark
    $time_per_seq = $jos->jos_min();

    # always interleave darks so number of darks
    $ndarks = $nseq;

  } elsif ($obs_type eq 'setup') {

    # We do not know how long a setup will take
    $nseq = 1;
    $time_per_seq = 240 / $eff_step_time; # in steps
    $ndarks = 1;

  } elsif ($map_mode eq 'stare' || $map_mode eq 'dream') {

    # Array tests will not have any
    my $noffsets = 1;
    my $nms = 1;
    if (defined $oa) {
      # Number of offsets and microsteps (1 is minimum)
      my @offsets = $oa->offsets;
      my @msoffsets = $oa->microsteps;
      $noffsets = (@offsets ? @offsets : 1);
      $nms = (@msoffsets ? @msoffsets : 1);
    }

    # number of sequences is number of offsets times the number of cycles
    $nseq = $noffsets * $nms * $jos->num_cycles;

    # integration time per sequence
    $time_per_seq = $jos->jos_min();

    # number of sequences per dark (minimum 1)
    my $nseq_per_dark = max( 1, POSIX::floor( $steps_btwn_darks / $time_per_seq ));

    # total number of darks
    $ndarks = POSIX::ceil( $nseq / $nseq_per_dark );

  } elsif ($map_mode eq 'scan') {

    # need to work out the duration of a single map area
    my $pattern = $oa->scan_pattern;

    my %scan = $oa->scan;
    my %map = $oa->maparea;

    # Variable for duration of a single map area
    my $steps_per_map = 0;

    if ($jos->jos_min() > 1) {
      # special case - this is simply the time we are going to spend on each "map" between darks
      $steps_per_map = $jos->jos_min;

    } elsif ($pattern =~ /raster|bous/i) {

      # make an estimate of the number of samples in the map area. Add one array diameter to longest dimension
      # and also add an extra 60 arcsec turn around area.
      my $inst = $self->instrument_setup();
      throw JAC::OCS::Config::Error::FatalError("Unable to determine duration since there is no instrument configuration")
        unless defined $inst;

      my $radius = $inst->array_radius;

      # work out map area
      my $minwidth = min( values %map );
      my $maxwidth = max( values %map );
      $maxwidth += (2 * $radius->arcsec) + 60.0;

      my $maparea = $minwidth * $maxwidth;

      # work out the sample size
      my $sample_area = $scan{DY} * ( $scan{VELOCITY} * $eff_step_time);

      # number of samples is the number of steps
      $steps_per_map = $maparea / $sample_area;

    } elsif ($pattern =~ /lissajous|pong/i) {

      my $time_per_map = JCMT::TCS::Pong::get_pong_dur( %map, %scan );
      $steps_per_map = $time_per_map / $eff_step_time;

    } elsif ( $pattern =~ /ellipse/i) {
      use Math::Trig ':pi';
      my $rx = $map{WIDTH};
      my $ry = $map{HEIGHT};
      # Calculate an approximate "radius" for the ellipse
      my $r = sqrt( ( $rx*$rx + $ry*$ry ) / 2.0 );
      my $perimeter = 2.0 * pi * $r;
      my $duration_per_area = $perimeter / $scan{VELOCITY};
      $steps_per_map = int( $duration_per_area / $eff_step_time + 0.5) + 1;

    } elsif ( $pattern =~ /daisy/i) {
      use Math::Trig ':pi';
      # From Per Friberg
      my $r0 = ($map{WIDTH}+$map{HEIGHT}) / 4;
      my $o = $map{VELOCITY} / $map{DY} / $r0;
      my $O = $o / 10.1;
      my $duration_per_area = 2.0 * pi / $O;
      $steps_per_map = int( $duration_per_area / $eff_step_time + 0.5) + 1;
    } else {
      JAC::OCS::Config::Error::FatalError->throw("Scan pattern '$pattern' not recognized");
    }

    # how many maps do we need
    my $nmaps = $jos->num_cycles;
    $nmaps = 1 if !$nmaps; # at least one

    # number of maps per dark
    my $nmaps_per_dark = max( 1, POSIX::floor( $steps_btwn_darks / $steps_per_map ) );

    # we are allowed to do 2 maps, dark, 2 maps, dark, 1 map so nseq can be an integer
    # but we need time_per_seq * nseq to get the total correct time (nmaps * steps_per_map)
    $ndarks = POSIX::ceil( $nmaps / $nmaps_per_dark );

    # number of darks is the number of sequences
    $nseq = ($ndarks > 0 ? $ndarks : 1);

    # but time per seq is not the real time per seq since that can change
    $time_per_seq = $nmaps * $steps_per_map / $nseq;

  } else {
    JAC::OCS::Config::Error::FatalError->throw("Unrecognized observing mode for duration calculation: '$map_mode/$obs_type'");

  }

  # if we are a focus we need to multiply by the number of focus positions
  if ($obs_type eq 'focus') {
    $nseq *= $jos->num_focus_steps();
  }

  print "NDARKS=$ndarks  NSEQ= $nseq  TIME/SEQ=".($eff_step_time*$time_per_seq)."\n"
    if $DEBUG;

  # calculate the duration

  # Overhead for all observations
  my $startup_overhead = 20.0;

  # overhead for each sequence
  my $seq_start_overhead = 2.0;

  # length of dark. A dark is a sequence.
  my $darklen = $jos->n_calsamples * $eff_step_time;

  # Convert time per sequence into seconds rather than steps
  $time_per_seq *= $eff_step_time;

  my $duration = $startup_overhead + (($ndarks + $nseq) * $seq_start_overhead)
    + ($time_per_seq * $nseq) + ($ndarks * $darklen);

  return Time::Seconds->new($duration);
}

=item B<duration_acsis>

ACSIS-specific calculation of observing duration. Currently we keep the
ACSIS and SCUBA-2 calculations separate until we work out whether there
is any commonality. No clever subclassing since there is no concept
(yet) of a JAC::OCS::Config::ACSIS subclass of JAC::OCS::Config.

=cut

sub duration_acsis {
  my $self = shift;

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

  # Secondary information
  my $secondary = $tcs->getSecondary;

  # Overheads
  # SETUP_SEQUENCE general overhead
  my $seq_overhead = 5.0;
  #  - observation start and end overhead
  my $obs_overhead = 40.0;
  #  - time per telescope move to reference (one way so that 
  #    we can take into account OFF ON ON OFF sequences
  my $tel_ref_overhead = 5.0;   # seconds
  #  - time per telescope move to NOD (one way so that A B B A sequences
  #    can be taken into account)
  my $tel_nod_overhead = 2.0;
  #  - time per SMU move (focus)
  my $smu_overhead = 2.0;
  #  - time per cal move (treat that the same as going to a reference)
  #    although for jiggle/chop it will only go to the chop beam.
  my $cal_overhead = $tel_ref_overhead;


  # get the base mapping modes
  my $map_mode = lc($obssum->mapping_mode);
  my $sw_mode  = lc($obssum->switching_mode);
  my $obs_type = lc($obssum->type);

  # A _spin switch mode is not relevant
  $sw_mode =~ s/_spin//;

  # Basic step time
  my $step = $jos->step_time;
  throw JAC::OCS::Config::Error::FatalError("JOS Steptime must be positive")
    unless $step > 0;

  # This will be the number of steps per cycle to complete the observation
  my $nsteps = 0;

  # Number of reference observations
  # Number of times we go to a reference.
  my $nrefs = 0;

  # Number of times we go to a reference and the number of times we come back
  # Not necessarily 2 times the number of
  # times we do a reference (because of OFF ON ON OFF). "1" for a single
  # visit, "2" if we need to go back to the targer.
  my $ntel_ref_moves = 0;

  # Number of steps spent on single reference
  my $nsteps_ref = 0;

  # Number of telescope nods (A->B or B->A)
  my $nnods = 0;

  # Number of SMU positions during the observations
  my $nsmu = 1;

  # Number of sequences started. A bit of a fudge factor
  my $nseq = 0;

  # Each mode needs a different calculation
  if ($obs_type =~ /skydip/) {
    # do not yet know

  } elsif ($map_mode =~ /(raster|scan)/) {

    # consistency check
    my $mode = $oa->mode;
    throw JAC::OCS::Config::Error::FatalError("Inconsistency in configuration. Scan map requested but obsArea does not specify a map area (mode='$mode' not 'area')") unless $mode =~ /area/i;

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

    print "Number of steps for map = $nsteps ($dx x $dy in $mapdims{HEIGHT} x $mapdims{WIDTH})\n" if $DEBUG;

    # Work out which edge we will be scanning relative to.
    # Square maps make this easy
    my $rowlen;
    my $ysize;
    if ($mapdims{HEIGHT} == $mapdims{WIDTH}) {
      $rowlen = $mapdims{HEIGHT};
      $ysize = $mapdims{WIDTH};
    } else {

      # Map position angle (pick the first angle if there are multiples)
      my $map_pa = $oa->posang->degrees;

      # Scan angles (relative to map position angle) normalised to
      # -PI to PI
      my @scan_pa = map { $map_pa - $_->degrees } @{$scan{PA}};
      @scan_pa = map { Astro::Coords::Angle->new($_, units => 'deg',
                                                 range => 'PI')->degrees
                                               } @scan_pa;

      # if the angle is 90 +/- 45 we are scanning along width
      # else we are scanning along height. If we have a choice
      # we choose the longest option

      my $choose;
      for my $ang (@scan_pa) {
        my $key = "HEIGHT";
        my $okey = "WIDTH";
        if (abs(90-$ang) <= 45) {
          # width
          $key = "WIDTH";
          $okey = "HEIGHT";
        }
        if (!defined $rowlen) {
          $rowlen = $mapdims{$key};
          $ysize = $mapdims{$okey};
        } elsif ($rowlen < $mapdims{$key}) {
          $rowlen = $mapdims{$key};
          $ysize = $mapdims{$okey};
        }
      }
    }

    # Work out how many scans we need
    my $nscans = ceil($ysize / $scan{DY});

    # number of steps in a row
    my $rsteps = ceil($rowlen / $dx);

    # number of rows per refs (must be smaller than steps_btwn_refs
    # but at least 1.
    my $nrows_per_ref = int( $jos->steps_btwn_refs / $rsteps);
    $nrows_per_ref = 1 if $nrows_per_ref < 1;

    # So the number of refs the total number of scans required
    # divided by the number of rows we can do per ref
    $nrefs = ceil($nscans / $nrows_per_ref);

    # Convert to number of reference steps
    $nsteps_ref = ceil( sqrt($nrows_per_ref*$rsteps) );

    # For scan/pssw we interpolate offs so the number of times we go to
    # reference is the same as the actual number of refs required. So number
    # of telescope moves is 2 times the number of refs with the last ref
    # not required to return
    $ntel_ref_moves = (2 * $nrefs) - 1;

    # at least 2
    $ntel_ref_moves = 2 if $ntel_ref_moves < 2;

    # Number of sequences is number of rows plus number of refs
    $nseq = $nrefs + $nscans;

  } elsif ($map_mode eq 'jiggle' && $sw_mode =~ /^(chop|freqsw)$/ ) {

    # ABBA nodding except for focus (AB)
    # No position switch

    # consistency check
    my $mode = $oa->mode;
    throw JAC::OCS::Config::Error::FatalError("Inconsistency in configuration. Grid requested but obsArea does not specify offset mode (mode='$mode' not 'offsets')")
      unless $mode =~ /offsets/i;

    # Work out how many offsets we have
    my @offsets = $oa->offsets;
    my $noffsets = scalar(@offsets);

    throw JAC::OCS::Config::Error::FatalError("Unable to determine duration since there is no secondary mirror information") unless defined $secondary;

    # and the number of points in the jiggle pattern
    my $jig = $secondary->jiggle;
    my $njigs = $jig->guess_npts;

    # since we are going for a ball park number we just assume
    # this controls the shared vs non-shared and do not attempt
    # to add chop overhead
    if ($secondary->smu_mode eq 'chop_jiggle') {
      # non-shared - repeated in off
      $nsteps = $jos->jos_mult * $njigs * 2;
    } elsif ($secondary->smu_mode eq 'jiggle_chop') {
      my %t = $secondary->timing;

      # time in the on
      $nsteps = $jos->jos_mult * $njigs;

      # time in the off
      my $nchunks = $njigs / $t{N_JIGS_ON};
      $nsteps += $nchunks * $t{N_CYC_OFF};
    } elsif ($secondary->smu_mode eq 'jiggle') {
      # no chopping
      $nsteps = $jos->jos_mult * $njigs;
    } else {
      throw JAC::OCS::Config::Error::FatalError("Unexpected smu mode: ".
                                                $secondary->smu_mode);
    }

    print "Nsteps = $nsteps\n" if $DEBUG;

    if ($sw_mode eq 'chop') {
      # Nod set size
      my $nod_set_size = 2;     # ABBA
      if ($obssum->type =~ /^(focus)/i) {
        $nod_set_size = 1;      # AB
      }

      # Number of nods (A -> B  + B -> A)
      # AB is the minimum set. Nod Set Size can be ABBA
      # include the offsetting
      $nnods = $jos->num_nod_sets * $nod_set_size * $noffsets;
      print "Number of nods = $nnods\n" if $DEBUG;

      # Total number of steps is twice this because each spectrum
      # is an AB
      $nsteps *= $nnods * 2;

      # Number of sequence starts
      $nseq = $nnods * 2;
    } elsif ($sw_mode eq 'freqsw') {
      print "No nodding\n" if $DEBUG;
      $nseq = $jos->num_cycles;

      # 2 switches for frequency switch
      $nsteps *= 2 * $jos->num_cycles;

    } else {
      throw JAC::OCS::Config::Error::FatalError("Unable to determine duration since there is an unexpected switch mode in jiggle: $sw_mode");
    }

  } elsif ($map_mode eq 'grid' && $sw_mode eq 'freqsw') {
    # Just offsets. No chopping or nodding

    # consistency check
    my $mode = $oa->mode;
    throw JAC::OCS::Config::Error::FatalError("Inconsistency in configuration. Grid requested but obsArea does not specify offset mode (mode='$mode' not 'offsets')")
      unless $mode =~ /offsets/i;

    # Work out how many offsets we have
    my @offsets = $oa->offsets;
    my $noffsets = scalar(@offsets);

    # Number of steps in a single sequence times the number of cycles
    $nsteps = $jos->jos_mult * 2 * $jos->num_cycles;

    # Number of sequence starts is just the number of offsets
    $nseq = $jos->num_cycles * $noffsets;

  } elsif ($map_mode eq 'grid' && $sw_mode eq 'chop') {

    # ABBA nodding
    # No position switch

    # consistency check
    my $mode = $oa->mode;
    throw JAC::OCS::Config::Error::FatalError("Inconsistency in configuration. Grid requested but obsArea does not specify offset mode (mode='$mode' not 'offsets')")
      unless $mode =~ /offsets/i;

    # Work out how many offsets we have
    my @offsets = $oa->offsets;
    my $noffsets = scalar(@offsets);

    # Number of steps in a single sequence including the off
    $nsteps = $jos->jos_mult * 2;

    # Nod set size
    my $nod_set_size = 2;       # ABBA
    if ($obssum->type =~ /^(focus)/i) {
      $nod_set_size = 1;        # AB
    }

    # Number of nods (A -> B  + B -> A)
    # includes all the offsets
    $nnods = $jos->num_nod_sets * $nod_set_size * $noffsets;

    # Total number of steps
    $nsteps *= $nnods * 2;

    # Number of sequence starts
    $nseq = $nnods * 2;


  } elsif ($map_mode =~ /grid|jiggle/ && $sw_mode eq 'pssw') {

    # consistency check
    my $mode = $oa->mode;
    throw JAC::OCS::Config::Error::FatalError("Inconsistency in configuration. Grid requested but obsArea does not specify offset mode (mode='$mode' not 'offsets')")
      unless $mode =~ /offsets/i;

    # Number of on is simply the number of offsets
    my @offsets = $oa->offsets;
    my $noffsets = scalar(@offsets);

    # and the number of jiggle positions
    my $njigs = 1;
    if ($map_mode =~ /jiggle/) {
      throw JAC::OCS::Config::Error::FatalError("Unable to determine duration since there is no secondary mirror information") unless defined $secondary;

      my $jig = $secondary->jiggle;
      $njigs = $jig->guess_npts;
    }

    # Number of chunks to break up the observation
    my $nchunks = $jos->num_cycles * $noffsets;

    # Number of steps on source = JOS_MIN
    # * the number of positions
    $nsteps = $nchunks * $jos->jos_min;

    print "Nchunks= $nchunks NStepsOn = $nsteps\n" if $DEBUG;

    # number of JOS_MIN we can fit into STEPS_BTWN_REFS
    my $n_chunks_per_ref = 1;
    if (@offsets > 1) {
      my $min_per_ref = int($jos->steps_btwn_refs / $jos->jos_min);
      if ($min_per_ref > 1 && $jos->shareoff) {
        $n_chunks_per_ref = $min_per_ref;
      }
    }

    # calculate the number of times we go to refs
    $nrefs = ceil($nchunks / $n_chunks_per_ref);

    # Length of a ref depends on shareoff
    if ($jos->shareoff) {
      if ($map_mode =~ /jiggle/) {
        # timing depends on the size of the jiggle pattern
        # and the number of times we have gone round it
        $nsteps_ref = ($jos->jos_min / $njigs) * sqrt($njigs);
      } else {
        # timing depends on the number of offsets we did per ON
        $nsteps_ref = $jos->jos_min * sqrt( $n_chunks_per_ref );
      }
    } else {
      # Not shared so we do JOS_MIN in the OFF
      # We do not do multiple offsets since we can not distribute the OFFs
      # across multiple sequences
      $nsteps_ref = $jos->jos_min;
    }

    # We observe as OFF ON ON OFF OFF ON ON OFF
    # number of telescope moves is therefore the number of refs
    # to a first approximation
    $ntel_ref_moves = $nrefs;

    # Sequence count fudge
    $nseq = $nrefs + $nchunks;

  } else {
    throw JAC::OCS::Config::Error::FatalError("Unrecognized mapping mode for duration calculation: $map_mode/$sw_mode");
  }

  # Total number of steps on+off and smu position
  my $npercyc = $nsteps + ( $nrefs * $nsteps_ref ) + ( $nnods * $nsteps_ref );
  print "Steps on+off = $npercyc\n" if $DEBUG;
  print "Nrefs * steps = $nrefs * $nsteps_ref\n" if $DEBUG;
  # if we are focus, multiply all this by the number of focus steps
  # This induces overhead
  if ($obssum->type =~ /^focus/i) {
    $nsmu = $jos->num_focus_steps;
  }

  # Total number of steps in entire observation
  my $ntot = $npercyc * $nsmu;

  # Approximate number of cals - needs the total number of steps
  # And make sure the cal is at least long enough for the ref
  my $cal_len = ($jos->n_calsamples || 0);
  $cal_len = max( $nsteps_ref, $cal_len ) if $cal_len;
  my $ncals = 0;
  if ($jos->n_calsamples > 0) {
    $ncals = ceil($ntot / $jos->steps_btwn_cals);
  }

  # Assume that if a cal can share the ref, that the number of steps
  # due to the SKY cal (Which we assume to dominate because the others
  # can be done in parallel) is the delta over the refs.
  print "Original length of cal = $cal_len  Steps per ref = $nsteps_ref\n" if $DEBUG;
  $cal_len = $cal_len - $nsteps_ref if $nrefs;
  $cal_len = 0 if $cal_len < 0;
  my $nsteps_cal = $cal_len * $ncals;

  # Focus and pointing are not calibrated
  if ($obssum->type =~ /(focus|pointing)/i) {
    $ncals = 0;
  }

  print "NCals = $ncals Nrefs = $nrefs nsteps_cal= $nsteps_cal Tel moves=$ntel_ref_moves\n"
    if $DEBUG;

  # Time per cycle, including overheads
  # Convert to an actual time
  my $duration = ( $npercyc * $step )         # on+off time
    + ( $ntel_ref_moves * $tel_ref_overhead ) # number of refs
      + ($nseq * $seq_overhead )              # sequence overhead
        + ( $nnods * $tel_nod_overhead);      # number of nods

  print "Duration=$duration TotSteps=$npercyc obs_overhead=$obs_overhead\n" if $DEBUG;

  # Take into account SMU moves (assumes NUM_CYCLES is inside SMU loop)
  # but in general the FOCUS recipe forces NUM_CYCLES = 1
  $duration *= $nsmu;
  $duration += ( $nsmu - 1 ) * $smu_overhead;

  # Take into account cal overhead
  if ($ncals > 0) {
    $duration += ( $nsteps_cal * $step ) + ( $ncals * $cal_overhead );
  }

  # General start up / shutdown overhead
  # probably should include average slew time
  $duration += $obs_overhead;

  print "\tEstimated Duration: $duration sec\n" if $DEBUG;

  # The answer!
  return Time::Seconds->new( $duration );
}

=item B<backend>

Acquisition system or correlator hardware.

  $backend = $cfg->backend();

Returns undef if there is insufficient information in the configuration.

=cut

sub backend {
  my $self = shift;
  my $backend;
  if (defined $self->acsis) {
    $backend = "acsis";
  } elsif (defined $self->scuba2) {
    $backend = "scuba2";
  }
  return $backend;
}


=item B<telescope>

Return the telescope name associated with this Config.
This value is synchronized with that stored in the
C<JCMT::OCS::Config::TCS> object (if present), overwriting
the current value if specified.

 $tel = $self->telescope;

Returned as a string rather than an C<Astro::Telescope> object.
The TCS_CONFIG value takes precedence if both are defined.

If the TCS configuration is not defined we rely on the instrument
backend.

=cut

sub telescope {
  my $self = shift;
  if ( @_ ) {
    $self->{Telescope} = shift;
    my $tcs = $self->tcs;
    $tcs->telescope( $self->{Telescope} ) if defined $tcs;
  }

  # return the current value
  my $tcs = $self->tcs;
  if (defined $tcs) {
    my $tcstel = $tcs->telescope;
    if (defined $tcstel) {
      return $tcstel;
    }
  } elsif (defined $self->backend) {
    # Flatfield and noise observations may not use the telescope
    my $backend = $self->backend;
    if ($backend eq 'scuba2' || $backend eq 'acsis') {
      $self->{Telescope} = "JCMT";
    }
  }
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
  # Can not modify
  return $self->_get_set_header_value( "PROJECT" );
}

=item B<msbid>

The MSB ID associated with this configuration. If none is defined
(e.g. if no HEADER_CONFIG available), then the method will return undef.

  $id = $cfg->msbid;

This method does assume a specific FITS header defines the MSB ID.

Can be used to set the value.

=cut

sub msbid {
  my $self = shift;
  return $self->_get_set_header_value( "MSBID", @_ );
}

=item B<msbtid>

MSB transaction ID. Can be used to set a value as well as retrieve.
Can only be set if the MSBTID header entry pre-exists.

  $cfg->msbtid( $msbtid );
  $tid = $cfg->msbtid();

=cut

sub msbtid {
  my $self = shift;
  return $self->_get_set_header_value( "MSBTID", @_ );
}

# Generic function for read something from the Header

sub _get_set_header_value {
  my $self = shift;
  my $header = $self->header;
  return undef unless defined $header;

  # get the item or items
  my $name = shift;
  my @items = $header->item( $name );
  return undef unless @items;

  if (@_) {
    my $new = shift;
    $items[0]->value( $new );
  }
  return $items[0]->value;
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

  my @components;

  my $mapmode = $obssum->mapping_mode;
  my $swmode  = $obssum->switching_mode;
  my $obstype = $obssum->type;
  my @inbeam = $obssum->inbeam;

  # in conjunction with the instrument information we should be able to make
  # things more targetted than blindly concatenating. For now drop "none"
  # from the switch description and drop "science" from the obs type since
  # these are default behaviours. Also drop "stare" from non-science
  # observations since it's only really news if it isn't stare.

  if (defined $mapmode) {
    # Not stare OR we are stare but the obstype is science.
    # Otherwise a "stare/science" observation comes out unknown.
    if ($mapmode ne 'stare' ||
       ( defined $obstype && $obstype eq 'science' ) ) {
      push(@components, $mapmode );
    }
  }
  if (defined $swmode) {
    if ( $swmode ne 'self' && $swmode ne 'none' ) {
      push(@components, $swmode )
    }
  }
  push(@components, $obstype) if (defined $obstype && $obstype ne 'science');

  # Something in the beam is very important
  push(@components, @inbeam);

  # Put something in if we still have no idea
  push(@components, "unknown") unless @components;

  return join("_", @components);
}

=item B<waveband>

Returns an C<Astro::WaveBand> object representing this configuration.

  $wb = $cfg->waveband;

=cut

sub waveband {
  my $self = shift;
  my $fe = $self->frontend;
  my $s2 = $self->scuba2;

  my $inst = $self->instrument_serial;

  if (defined $fe) {
    my $rfreq = $fe->rest_frequency;
    my $wb = new Astro::WaveBand( 
                                 Frequency => $rfreq,
                                 Instrument => $inst,
                                );

    return $wb;
  } elsif (defined $s2) {
    my $wb = Astro::WaveBand->new( Instrument => "SCUBA-2",
                                   Filter => "850");
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

  # We set things up so that Skydips do require a target
  # even if it is a "do at current position"
  # target. Setups will be missing a TCS_CONFIG if current location
  # is used. Other setups require an explicit target.
  if ($obs =~ /(scan|dream|stare|raster|jiggle|grid|skydip|setup|noise)/i) {

    # Get the TCS object
    my $tcs = $self->tcs;
    if (defined $tcs) {

      # Get the target information
      my $c = $tcs->getTarget;
      if ( !defined $c) {
        if ($obs =~ /(setup|skydip|noise)/i ) {
          # Skydips and setups can be setup with dummy target indicating
          # we need to fill in something or else can be configured with
          # no target information at all (which is fine)
          my %tags = $tcs->tags;

          # if we have tags but did not have a SCIENCE coordinate then we assume
          # we are missing a target but need the next target
          if (keys %tags) {
            throw JAC::OCS::Config::Error::NeedNextTarget("No science target defined in configuration");
          }

        } else {
          throw JAC::OCS::Config::Error::MissingTarget("No science target defined in configuration");
        }
      }
    } elsif ($obs !~ /setup|noise/i) {
      throw JAC::OCS::Config::Error::FatalError( "No TCS definition available in this configuration");
    }
  }

}

=item B<targetIsCurrentAz>

Returns true if there is a TCS config associated with the configuration
and it corresponds to the current location of the telescope rather than
a particular coordinate.

 $iscur = $cfg->targetIsCurrentAz;

Returns true if current azimuth. Otherwise returns false. Only relevant
for skydip, setup and noise observations. All other obs types return false.

Not a TCS method because the obs type is required.

=cut

sub targetIsCurrentAz {
  my $self = shift;

  # Do we have a TCS?
  my $tcs = $self->tcs;
  return 0 unless defined $tcs;

  # get the observing mode and make sure that we need a target
  my $obs = $self->obsmode;

  # Special case for these. Current Az if there are no tags
  # associated with the TCS configuration. Any tags at all
  # implies we either have a target or we have stored a dummy
  # FOLLOWINGAZ tag.
  if ($obs =~ /skydip|setup|noise/i) {
    my %tags = $tcs->tags;
    if (keys %tags) {
      return 0;
    } else {
      return 1;
    }
  }
}

=item B<targetIsFollowingAz>

Returns true if there is a TCS config associated with the configuration
and it corresponds to a hint to use the azimuth of some target yet
undetermined.

 $isfoll = $cfg->targetIsFollowingAz;

Returns true if following azimuth. Otherwise returns false. Only relevant
for skydip, setup and noise observations although the observing mode
is not tested. The only requirement is the presence of the special
FOLLOWINGAZ tag.

Calls the TCS hasFollowingTag() method.

=cut

sub targetIsFollowingAz {
  my $self = shift;

  # Do we have a TCS?
  my $tcs = $self->tcs;
  return 0 unless defined $tcs;
  return $tcs->hasFollowingTag;
}


=item B<fixup>

Correct any run time problems with the configuration. Assumes the
modifications are for the current time.

  my @messages = $cfg->fixup;

No config modifications are done at this time, other than those
implemented by the JAC::OCS::Config::TCS object.

=cut

sub fixup {
  my $self = shift;
  my @messages = ();

  my $tcs = $self->tcs;
  push @messages, $tcs->fixup($self->duration(), $self->jos()) if defined $tcs;

  return @messages;
}

=item B<iscal>

Returns true if the configuration seems to be associated with a
science calibration observation (e.g. a flux or wavelength
calibration). Returns false otherwise.

  $iscal = $cfg->iscal();

=cut

sub iscal {
  my $self = shift;
  my @flags = $self->_cal_flags();
  return $flags[1];
}

=item B<isGenericCal>

Returns true if the observation is a generic calibration (for example pointing
or focus).

  $cfg->isGenericCal;

Returns false if this can not be determined.

=cut

sub isGenericCal {
  my $self = shift;
  my @flags = $self->_cal_flags();
  return $flags[0];
}

=item B<isScienceObs>

Returns true if the observation is a science observation and
not a calibration observation.

Returns false if not enough information is available.

=cut

sub isScienceObs {
  my $self = shift;
  my @flags = $self->_cal_flags();
  return $flags[2];
}

# Since the calibration flags depend on all the same information
# we write a simple routine that can be called from iscal, isScienceObs
# and isGenericCal

# ($isgencal, $iscal, $isscience) = $self->_cal_flags();

# returns false for each value if insufficient information is available.

sub _cal_flags {
  my $self = shift;

  # get the observation summary and the header configuration
  my $obssum = $self->obs_summary;
  return (0,0,0) unless defined $obssum;

  # Non-science means generic cal
  my $type = $obssum->type;
  return (1,0,0) if lc($type) ne 'science';

  # Header is required to distinguish cal from non-cal science
  my $hdr = $self->header;
  return (0,0,0) unless defined $hdr;

  my $std = $hdr->item( "STANDARD" );

  if ($std) {
    # science standard
    return (0,1,0);
  } else {
    # science observation
    return (0,0,1);
  }

}

=item B<isMissingTarget>

An observation that would require a target but is currently missing one.

 $ismiss = $cfg->isMissingTarget();

Returns false if there is no TCS information at all or if a target
is specified. FollowingAz, CurrentAz and Zenith targets also return
false.

=cut

sub isMissingTarget {
  my $self = shift;
  my $obsmode = $self->obsmode;
  my $tcs = $self->tcs;
  if (defined $tcs) {
    my $c = $tcs->getTarget;
    return 0 if defined $c;

    my $follow = $tcs->getCoords( $JAC::OCS::Config::TCS::FOLLOWINGTAG );
    if ($obsmode =~ /setup|skydip/i || defined $follow ) {
      return 0;
    } else {
      # Check for zenith mode
      my $oa = $tcs->getObsArea;
      if ($oa->is_zenith_mode || $oa->is_sky_mode ) {
        return 0;
      } else {
        # No target yet but we will need to fill one in
        return 1;
      }
    }
  }
  return 0;
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

  # Make sure that we have the correct task names
  $self->_sync_cont_status();

  # Get the repository version information
  my $repover = JAC::OCS::Config::Version::version();

  # Standard declaration plus DTD
  $xml .= '<?xml version="1.0" encoding="US-ASCII"?>' .
    '<!DOCTYPE OCS_CONFIG  SYSTEM  "/jac_sw/itsroot//ICD/001/ocs.dtd">' .
      "\n";

  $xml .= "<OCS_CONFIG>\n";

  # Insert any comment. Including a default comment.
  my $comment = "Rendered as XML on ". gmtime() . "UT using Perl module\n";
  $comment .= ref($self) . " version $VERSION ($repover)\nPerl version $]\n";
  $comment .= "\@INC =\n". join("\n  ", @INC);
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

Default output directory for writing the OCS configuration. Currently
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

=item B<outhdl>

Output file handles to use for verbose messages.
Defaults to STDOUT.

  JAC::OCS::Config->outhdl( \*STDOUT, $fh );

Returns an C<IO::Tee> object.

Pass in undef to reset to the default.

=cut

{
  my $def = new IO::Tee(\*STDOUT);
  my $oh = $def;
  sub outhdl {
    my $class = shift;
    if (@_) {
      if (!defined $_[0]) {
        $oh = $def;             # reset
      } else {
        $oh = new IO::Tee( @_ );
      }
    }
    return $oh;
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

=item B<qtarget>

The summary target string associated with the queue entry.

  $targstr = $ocs->qtarget();

=cut

sub qtarget {
  my $self = shift;
  my $obsmode = $self->obsmode;

  # target name
  my $targ = 'NONE';
  my $tcs = $self->tcs;
  if (defined $tcs) {
    my $c = $tcs->getTarget;
    my $tcstarg;
    $tcstarg= $c->name if (defined $c && defined $c->name);
    if ($tcstarg) {
      $tcstarg =~ s/\s+$//;
      $targ = $tcstarg;
    } else {
      # in the special case of skydip or setup we need to distinguish
      # current AZ from next target. For NOISE we want to keep
      # an eye out for Zenith or Sky noise at current AZ
      my $follow = $tcs->getCoords( $JAC::OCS::Config::TCS::FOLLOWINGTAG );
      if ($obsmode =~ /setup|skydip/i || defined $follow ) {
        if (defined $follow) {
          $targ = "FollowingAz";
        } else {
          # No dummy so we want to observe HERE
          $targ = "CurrentAz";
        }
      } else {
        # Check for zenith mode
        my $oa = $tcs->getObsArea;
        if ($oa->is_zenith_mode) {
          $targ = "Zenith";
        } elsif ( $oa->is_sky_mode ) {
          $targ = "CurrentAz";
        } else {
          # No target yet but we will need to fill one in
          $targ = "TBD";
        }
      }
    }
  } elsif ($obsmode =~ /setup/i) {
    # We really mean current Azimuth if we don't have a target
    $targ = "CurrentAz";
  } elsif ($obsmode =~ /blackbody/i) {
    # move the black body to the target name
    $targ = "BlackBody";
    $obsmode =~ s/\s*blackbody//;
  } else {
    my $jos = $self->jos;
    my $shutter = $jos->shut_frac;
    if (defined $shutter) {
      if ($shutter == 0) {
        $targ = "Dark";
      }
    }
  }

  return $targ;
}

=item B<qsummary>

Provide a simple one line summary suitable for display by the queue.
Will not include the project ID or estimated duration.

=cut

sub qsummary {
  my $self = shift;
  my $obsmode = $self->obsmode;
  my $instrument = $self->instrument_serial;
  my $targ = $self->qtarget;

  my $str;

  $obsmode =~ s/_/ /g;
  $str = sprintf("%-10s %-7s %-16s",$targ, $instrument,$obsmode);
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

=item B<_sync_cont_status>

Synchronizes "continuum" mode in all child configurations that
require the information.

=cut

sub _sync_cont_status {
  my $self = shift;
  my $iscont;
  for my $method ( "pol" ) {
    my $value = $self->$method();
    if (defined $value) {
      $iscont = $self->is_cont() unless defined $iscont; # cache
      $value->is_cont( $iscont );
    }
  }
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

  $cfg = find_children( $el, "SCUBA2_CONFIG", min => 0, max => 1);
  $self->scuba2( new JAC::OCS::Config::SCUBA2( DOM => $cfg) ) if $cfg;

  $cfg = find_children( $el, "INSTRUMENT", min => 0, max => 1);
  $self->instrument_setup( new JAC::OCS::Config::Instrument( DOM => $cfg) )
    if $cfg;

  $cfg = find_children( $el, "FRONTEND_CONFIG", min => 0, max => 1);
  $self->frontend( new JAC::OCS::Config::Frontend( DOM => $cfg) ) if $cfg;

  $cfg = find_children( $el, "RTS_CONFIG", min => 0, max => 1);
  $self->rts( new JAC::OCS::Config::RTS( DOM => $cfg) ) if $cfg;

  $cfg = find_children( $el, "POL_CONFIG", min => 0, max => 1);
  $self->pol( new JAC::OCS::Config::POL( DOM => $cfg) ) if $cfg;

  # we have finished the parse so set continuum status
  $self->_sync_cont_status();

  return;
}

=back

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2007 Science and Technology Facilities Council.
Copyright (C) 2004-2007 Particle Physics and Astronomy Research Council.
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
