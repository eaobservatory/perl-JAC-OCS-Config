#!perl

use Test::More tests => 2;

use_ok('JAC::OCS::Config::Version');

$sha = JAC::OCS::Config::Version::version();

like($sha, qr/^[a-f0-9]{40}$/);
