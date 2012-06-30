#!perl

use Test::More tests => 41;
use strict;

# This test script uses 3 sample pieces of XML, one for each of
# the FTS-2 operating modes.  In each case the XML is turned into
# a JAC::OCS::Config::FTS2 object, and checked against the input XML.

# Validation of the sample XML is off until the DTD is installed.

BEGIN {
  use_ok( "JAC::OCS::Config::FTS2" );
}

my $sample_rapid = '<FTS2_CONFIG>
   <SCAN_MODE VALUE="RAPID_SCAN" />
   <SCAN_DIR VALUE="DIR_ARBITRARY" />
   <SCAN_ORIGIN UNIT="mm">30</SCAN_ORIGIN>
   <SHUT8C VALUE="OUTOFBEAM" />
   <SHUT8D VALUE="OUTOFBEAM" />
   <SCAN_SPD UNIT="mm/s">10</SCAN_SPD>
   <SCAN_LENGTH UNIT="mm">170.0</SCAN_LENGTH>
</FTS2_CONFIG>';

my $cfg = new JAC::OCS::Config::FTS2(XML => $sample_rapid, validation => 0);

my $xml_out = "$cfg";

is(strip_xml($xml_out), $sample_rapid, 'Rapid scan sample re-XMLified');

ok( $cfg->is_rapid_scan(), 'Rapid scan is rapid scan');
ok(!$cfg->is_step_and_integrate(), 'Rapid scan is not step and integrate');
ok(!$cfg->is_zpd_mode(), 'Rapid scan is not ZPD mode');
ok(!$cfg->is_left_direction(), 'Rapid scan is not to the left');
ok( $cfg->is_arbitrary_direction(), 'Rapid scan has arbitrary direction');
ok(!$cfg->is_right_direction(), 'Rapid scan is not to the right');
ok(!$cfg->is_shutter_8c_in_beam(), 'Rapid scan shutter 8C not in beam');
ok(!$cfg->is_shutter_8d_in_beam(), 'Rapid scan shutter 8D not in beam');

is($cfg->scan_origin(), 30, 'Rapid scan origin');
is($cfg->scan_spd(), 10, 'Rapid scan speed');
is($cfg->scan_length(), '170.0', 'Rapid scan length');
is($cfg->step_dist(), undef, 'Rapid scan step distance');



my $sample_step = '<FTS2_CONFIG>
   <SCAN_MODE VALUE="STEP_AND_INTEGRATE" />
   <SCAN_DIR VALUE="DIR_LEFT" />
   <SCAN_ORIGIN UNIT="mm">31</SCAN_ORIGIN>
   <SHUT8C VALUE="OUTOFBEAM" />
   <SHUT8D VALUE="INBEAM" />
   <STEP_DIST UNIT="mm">0.2</STEP_DIST>
</FTS2_CONFIG>';

$cfg = new JAC::OCS::Config::FTS2(XML => $sample_step, validation => 0);

$xml_out = "$cfg";

is(strip_xml($xml_out), $sample_step, 'Step and integrate sample re-XMLified');

ok(!$cfg->is_rapid_scan(), 'Step and integrate is not rapid scan');
ok( $cfg->is_step_and_integrate(), 'Step and integrate is step and integrate');
ok(!$cfg->is_zpd_mode(), 'Step and integrate is not ZPD mode');
ok( $cfg->is_left_direction(), 'Step and integrate is to the left');
ok(!$cfg->is_arbitrary_direction(), 'Step and integrate not arbitrary');
ok(!$cfg->is_right_direction(), 'Step and integrate is not to the right');
ok(!$cfg->is_shutter_8c_in_beam(), 'Step and integrate shutter 8C not in beam');
ok( $cfg->is_shutter_8d_in_beam(), 'Step and integrate shutter 8D not in beam');


is($cfg->scan_origin(), 31, 'Step and integrate origin');
is($cfg->scan_spd(), undef, 'Step and integrate speed');
is($cfg->scan_length(), undef, 'Step and integrate length');
is($cfg->step_dist(), 0.2, 'Step and integrate step distance');



my $sample_zpd = '<FTS2_CONFIG>
   <SCAN_MODE VALUE="ZPD_MODE" />
   <SCAN_DIR VALUE="DIR_RIGHT" />
   <SCAN_ORIGIN UNIT="mm">314</SCAN_ORIGIN>
   <SHUT8C VALUE="INBEAM" />
   <SHUT8D VALUE="OUTOFBEAM" />
</FTS2_CONFIG>';

$cfg = new JAC::OCS::Config::FTS2(XML => $sample_zpd, validation => 0);

$xml_out = "$cfg";

is(strip_xml($xml_out), $sample_zpd, 'ZPD sample re-XMLified');

ok(!$cfg->is_rapid_scan(), 'ZPD mode is not rapid scan');
ok(!$cfg->is_step_and_integrate(), 'ZPD mode is not step and integrate');
ok( $cfg->is_zpd_mode(), 'ZPD mode is ZPD mode');
ok(!$cfg->is_left_direction(), 'ZPD mode is not to the left');
ok(!$cfg->is_arbitrary_direction(), 'ZPD mode not arbitrary');
ok( $cfg->is_right_direction(), 'ZPD mode is to the right');
ok( $cfg->is_shutter_8c_in_beam(), 'ZPD mode shutter 8C not in beam');
ok(!$cfg->is_shutter_8d_in_beam(), 'ZPD mode shutter 8D not in beam');


is($cfg->scan_origin(), 314, 'ZPD mode origin');
is($cfg->scan_spd(), undef, 'ZPD mode speed');
is($cfg->scan_length(), undef, 'ZPD mode length');
is($cfg->step_dist(), undef, 'ZPD mode step distance');



my $construct_rapid = '<FTS2_CONFIG>
   <SCAN_MODE VALUE="RAPID_SCAN" />
   <SCAN_DIR VALUE="DIR_LEFT" />
   <SCAN_ORIGIN UNIT="mm">65</SCAN_ORIGIN>
   <SHUT8C VALUE="OUTOFBEAM" />
   <SHUT8D VALUE="INBEAM" />
   <SCAN_SPD UNIT="mm/s">7</SCAN_SPD>
   <SCAN_LENGTH UNIT="mm">170.0</SCAN_LENGTH>
   <STEP_DIST UNIT="mm">0.25</STEP_DIST>
</FTS2_CONFIG>';

$cfg = new JAC::OCS::Config::FTS2();

$cfg->scan_mode('RAPID_SCAN');
$cfg->scan_dir('DIR_LEFT');
$cfg->scan_origin(65);
$cfg->scan_spd(7);
$cfg->scan_length('170.0');
$cfg->step_dist('0.25');
$cfg->shutter_8c('OUTOFBEAM');
$cfg->shutter_8d('INBEAM');

$xml_out = "$cfg";

is(strip_xml($xml_out), $construct_rapid, 'Rapid scan constructed');



# Assumes whole line block comments and gets rid of them.
sub strip_xml {
  my $xml = shift;
  my $comment = 0;
  my @out;
  foreach (split "\n", $xml) {
    if (/<!--/) {
      $comment ++;
      next;
    }
    elsif ($comment and /-->/) {
      $comment = 0;
      next;
    }

    push @out, $_ unless $comment;
  }

  return join("\n", @out);
}
