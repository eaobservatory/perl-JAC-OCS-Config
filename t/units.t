#!perl

use Test::More tests => 37;
use JAC::OCS::Config::ACSIS;
BEGIN {
  use_ok( "JAC::OCS::Config::Units" );
}

my %units = (
	     MHz => {
		     name => "hertz",
		     symbol => 'Hz',
		     prefix => 'M',
		     factor => 6,
		     fullprefix => 'mega',
		    },
	     Glm => {
		     name => "lumen",
		     symbol => 'lm',
		     prefix => 'G',
		     factor => 9,
		     fullprefix => 'giga',
		    },
	     mum => {
		     name => "metre",
		     symbol => 'm',
		     prefix => 'mu',
		     factor => -6,
		     fullprefix => 'micro',
		    },
	     ZJy => {
		     name => "jansky",
		     symbol => 'Jy',
		     prefix => 'Z',
		     factor => 24,
		     fullprefix => 'yotta',
		    },
	     daPa => {
		     name => "pascal",
		     symbol => 'Pa',
		     prefix => 'da',
		     factor => 1,
		     fullprefix => 'deca',
		    },
	     g => {
		     name => "gram",
		     symbol => 'g',
		     prefix => '',
		     factor => 0,
		     fullprefix => '',
		    },


	    );


for my $ustr (keys %units) {
  my $u = new JAC::OCS::Config::Units($ustr);

  is($u->unit, $ustr, "Compare recombined symbol '$ustr'");
  for my $m (keys %{ $units{$ustr} } ) {
    is($u->$m, $units{$ustr}->{$m}, "Compare $m");
  }
}
