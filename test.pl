#!/usr/local/bin/perl -w
use strict;
use Carp 'confess', 'croak';
use Test;

# use lib '../../';  # TESTING
use Data::Taxi;    # TESTING


BEGIN { plan tests => 1 };


my ($struct, $hold);

$struct = 
	{
	
	name => 'Miko',
	
	schools => [
		'Cardinal Forest',
		'Robinson',
		'VA Tech',
		],
	};

$hold = Data::Taxi::freeze($struct);
$struct = Data::Taxi::thaw($hold);

if ($struct->{'schools'}->[1] eq 'Robinson')
	{ok 1}
else
	{ok 0}
