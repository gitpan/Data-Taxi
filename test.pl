#!/usr/bin/perl -w
use strict;
use Carp 'confess', 'croak';
use Test;
use Data::Taxi;    # TESTING


BEGIN { plan tests => 1 };


my ($struct, $hold);

$struct = {
	name => 'Miko',
	
	schools => [
		'Cardinal Forest',
		'Robinson',
		'VA Tech',
	],
};

$hold = Data::Taxi::freeze($struct);

# die "early exit\n";

$struct = Data::Taxi::thaw($hold);

if ($struct->{'schools'}->[1] eq 'Robinson')
	{ok 1}
else
	{ok 0}
