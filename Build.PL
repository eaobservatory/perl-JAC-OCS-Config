#!perl

use strict;
use warnings;
use Module::Build;

# Handle creation of JAC::OCS::Config::Version.pm on the fly reading the git repository
my $class = Module::Build->subclass(
                                    class => "Module::Build::CustomOCSConfig",
                                    code  => join("", <DATA> ),
                                   );


# Now configure it further
my $build = $class->new
  (
   module_name => 'JAC::OCS::Config',
   license  => 'gpl',
   dist_abstract => 'JCMT OCS Configuration file parsing and writing',
   dist_author => 'Tim Jenness <t.jenness@jach.hawaii.edu>',
   meta_merge => {
               resources =>  {repository => "git://github.com/eaobservatory/perl-JAC-OCS-Config.git"},
                },
   requires => {
                'perl'          => '5.8.0',
                'IO::Tee'       => 0,
                'XML::LibXML'  => 0,
                'Astro::Coords' => 0.05,
                'Astro::Coords::Offset' => 0,
                'Astro::Coords::TLE' => 0,
                'JCMT::SMU::Jiggle' => 0,
                'JCMT::TCS::Pong' => 0,
                'JCMT::ACSIS::HWMap' => 0,
               },
   build_requires => {
                      'Test::More' => 0,
                      'Test::Number::Delta' => 0,
                     },
   configure_requires => {
                          'Module::Build' => '0.30',
                         },
   script_files => [ qw/ ocsconfig / ],
  );

$build->create_build_script;


# This is the subclass code to handle dynamic generation of the git version
# status when running Build
# Always generate this file. The overhead is small and we want to make sure that
# it is correct whenever the module is built. No reason to use something cleverer.
__DATA__

use File::Spec;
use warnings;
use strict;

sub ACTION_build {

  my $self = shift;
  my $curversion;
  $curversion = `git rev-parse --verify HEAD`;
  die "Could not read the git version information. Not proceeding until this is fixed."
    unless defined $curversion;
  chomp($curversion);

  print "Creating Version.pm with version $curversion...\n";

  open ( my $newfh, ">", File::Spec->catfile( "lib","JAC","OCS","Config", "Version.pm" ) )
    or die "Could not open Version.pm: $!";

  print $newfh qq|
# This module is created dynamically when building JAC::OCS::Confg
# Do not EDIT
# Modify Build.PL to change the contents.

package JAC::OCS::Config::Version;

=head1 NAME

JAC::OCS::Config::Version - Return repository version identifier

=head1 SYNOPSIS

  use JAC::OCS::Config::Version

  \$sha = JAC::OCS::Config::Version::version();

=head1 DESCRIPTION

This module can be used to obtain the SHA1 commit identifier associated with
the JAC::OCS::Config git repository. This module is dynamically created at 
build time. Note that git uses a 40 byte SHA1 string to identify versions
so \$JAC::OCS::Config::VERSION can not be used to determine the real state
of the module. \$VERSION will change much slower than the SHA1.

=cut

use strict;
sub version {
  return '$curversion';
};

=head1 AUTHOR

Tim Jenness E<lt>t.jenness\@jach.hawaii.eduE<gt>

Copyright (C) 2009 Science & Technology Facilities Council.
All Rights Reserved.

=cut

1;

|;

  close ($newfh) or die "Could not close Version.pm: $!";

  $self->SUPER::ACTION_build;
}

# Remove the Version.pm file

sub ACTION_clean {
  my $self = shift;
  # do not care about errors
  unlink File::Spec->catfile( "lib","JAC","OCS","Config", "Version.pm" );
  $self->SUPER::ACTION_clean;
}
