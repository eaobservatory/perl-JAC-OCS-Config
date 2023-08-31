#!perl

use strict;
use Test::More tests => 9;

use_ok('JAC::OCS::Config::Header');

my $header = JAC::OCS::Config::Header->new(
    XML => '<?xml version="1.0" encoding="US-ASCII"?>
        <HEADER_CONFIG>
            <HEADER TYPE="STRING" KEYWORD="MSBTITLE"
                COMMENT="Title of minimum schedulable block"
                VALUE="Version for elevation &lt; 40&#176;" />
        </HEADER_CONFIG>',
    validation => 0);

isa_ok($header, 'JAC::OCS::Config::Header');

my @items = $header->items();
is((scalar @items), 1);

my $item = @items[0];
isa_ok($item, 'JAC::OCS::Config::Header::Item');

is($item->keyword, 'MSBTITLE');
is($item->type, 'STRING');
is($item->comment, 'Title of minimum schedulable block');
is($item->value, "Version for elevation < 40\x{B0}");

my $xml = "$header";
like($xml, qr/VALUE="Version for elevation &lt; 40&#xB0;"/);
