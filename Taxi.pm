package Data::Taxi;
use strict;
use vars ('$VERSION', '$FORMAT_VERSION', '%HANDLE_FORMATS');
use Carp 'croak';
use 5.006;


=head1 NAME

Data::Taxi - Taint-aware, XML-ish data serialization

=head1 SYNOPSIS

  use Data::Taxi ':all';
  my ($ob, $str);
  
  $ob = MyClass->new();
  $str = freeze($ob);
  $ob = thaw($str);



=head1 DESCRIPTION

Taxi (B<T>aint-B<A>ware B<X>ML-B<I>sh) is a data serializer with several handy features:

=over

=item Taint aware

Taxi does not force you to trust the data you are serializing.
None of the input data is executed.

=item Human readable

Taxi produces a human-readable string that simplifies checking the
output of your objects.

=item XML-ish

While I don't (currently) promise full XML compliance, Taxi produces a block
of XML-ish data that could probably be read in by other XML parsers.

=back


=cut

#------------------------------------------------------------------------
# import/export
# 

=head1 EXPORT

None by default.  freeze and thaw with ':all':

   use Data::Taxi ':all';

=cut

use vars '@EXPORT_OK', '%EXPORT_TAGS', '@ISA';
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(freeze thaw);
%EXPORT_TAGS = ('all' => [qw(freeze thaw)]);
# 
# import/export
#------------------------------------------------------------------------


# version
$VERSION = '0.90';
$FORMAT_VERSION = '1.00';
undef $HANDLE_FORMATS{$FORMAT_VERSION};


# constants
use constant HASHREF  => 1;
use constant ARRREF   => 2;
use constant SCAREF   => 3;
use constant SCALAR   => 4;


=head1 Subroutines

=cut




#-----------------------------------------------------------------------------------
# freeze
# 

=head2 freeze($ob)

C<freeze> serializes a single scalar, has reference, array reference, or
scalar references into an XML string, C<freeze> can recurse any number of 
levels of a nested tree and preserve  multiple references to the same object. 
Let's look at an example:

	my ($tree, $format, $members, $bool, $mysca);

	# anonymous hash
	$format = {
		'app'=>'trini',
		'ver'=>'0.9',
		'ver'=>'this &amp; that',
	};
	
	# anonymous array
	$members = ['Starflower', 'Mary', 'Paul', 'Hallie', 'Ryan'];
	
	# blessed object
	$bool = Math::BooleanEval->new('whatever');

	# scalar reference (to an anonymous hash, no less)
	$mysca = {'name'=>'miko', 'email'=>'miko@idocs.com', };

	# the whole thing
	$tree = {
		'dataformat' => $format,
		'otherdataformat' => $format,
		'bool' => $bool,
		'members' => $members,
		'myscaref' => \$mysca,
	};

	$frozen = freeze($tree);

C<freeze> accepts one object as input.  The code above results in the following
XML-ish string:

   <taxi ver="1.00">
      <hashref id="0">
         <hashref name="otherdataformat" id="1">
            <scalar name="ver" value="this &#38;amp; that"/>
            <scalar name="app" value="trini"/>
         </hashref>
         <scalarref name="myscaref" id="2">
            <hashref id="3">
               <scalar name="email" value="miko@idocs.com"/>
               <scalar name="name" value="miko"/>
            </hashref>
         </scalarref>
         <hashref name="bool" id="4" class="Math::BooleanEval">
            <hashref name="blanks" id="5">
            </hashref>
            <scalar name="pos" value="0"/>
            <arrayref name="arr" id="6">
               <scalar value="whatever"/>
            </arrayref>
            <scalar name="expr" value="whatever"/>
         </hashref>
         <hashref name="dataformat" id="1" redundant="1"/>
         <arrayref name="members" id="7">
            <scalar value="Starflower"/>
            <scalar value="Mary"/>
            <scalar value="Paul"/>
            <scalar value="Hallie"/>
            <scalar value="Ryan"/>
         </arrayref>
      </hashref>
   </taxi>


=cut

# Golly, and after all that POD, the subroutine is only a few lines
# long. All the work is done in obtag(), which recurses through the
# data to build the data string.

sub freeze {
	return 
		'<taxi ver="' . $Data::Taxi::FORMAT_VERSION . "\">\n" . 
		join('',  obtag($_[0], {}, 1)) . 
		"</taxi>\n";
}
# 
# freeze
#-----------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------
# obtag
# 
# Private subroutine: recurses through data structure building the data string.
# 
sub obtag {
	my ($ob, $ids, $depth, $name) = @_;
	my ($ref, @rv, $indent);

	# build the indentation string for this recursion.
	$indent = "\t" x $depth;
	
	# if reference
	if ($ref = ref($ob)) {
		my $tagname = "$ob";
		my $org = $tagname;
		
		$tagname =~ s|^[^\=]*\=||;
		$tagname =~ s|\(.*||;
		$tagname = lc($tagname) . 'ref';
		
		# open tag
		push @rv, $indent, '<', $tagname;
		
		if (defined $name)
			{push @rv, ' name="', mlesc($name), '"'}
		
		# if in $ids
		if ($ids->{$ob})
			{return @rv, ' id="', $ids->{$ob}, '" redundant="1"/>', "\n"}
		
		# store object in objects hash
		# $ids->{$ob} = 1;
		$ids->{$ob} = keys(%{$ids});
		

		# output ID
		# push @rv, ' id="', mlesc($ob), '"';
		push @rv, ' id="', $ids->{$ob}, '"';

		
		if ($ref !~ m/^(HASH|ARRAY|REF)$/)
			{push @rv, ' class="', mlesc($ref), '"'}
		
		# close tag
		push @rv, ">\n";
		
		# output children: hashref
		if ($tagname eq 'hashref') {
			while( my($k, $v) = each(%{$ob}) )
				{push @rv, obtag($v, $ids, $depth + 1, $k)}
		}
		
		# output children: arrayref
		elsif ($tagname eq 'arrayref') {
			foreach my $v ( @{$ob} )
				{push @rv, obtag($v, $ids, $depth + 1)}
		}
		
		# output children: scalarref
		elsif ($tagname eq 'scalarref')
			{ push @rv, obtag(${$ob}, $ids, $depth + 1) }
		
		# else don't know this type of reference
		else
			{die "don't know this type of reference: $tagname"}
		
		# close tag
		push @rv, $indent, '</', $tagname, ">\n";
	}

	# else output tag with self-ender
	else {
		push @rv, $indent, '<scalar';

		if (defined $name)
			{push @rv, ' name="', mlesc($name), '"'}

		if (defined $ob)
			{push @rv, ' value="', mlesc($ob), '"'}

		push @rv, "/>\n";
	}

	return @rv;
}
# 
# obtag
#-----------------------------------------------------------------------------------



#-----------------------------------------------------------------------------------
# thaw data
# 

=head2  thaw

C<thaw> accepts one argument, the serialized data string, and returns a single value, the reconstituted data, rebuilding 
the entire data structure including blessed references. 

   $tree = thaw($frozen);

=cut

sub thaw {
	my ($raw) = @_;
	my (@els, @stack, %ids, %esc, $quote, $left, $right, $amp, $firstdone);
	
	# remove XML document header, we're not s'fisticaded 'nuff for that kinda thang yet.
	# XML gurus will wince at this code. 
	if ($raw =~ s|^\<\?||)
		{$raw =~ s|^[^\>]*>||}


	#-------------------------------------------------------------
	# placeholders for un-escaping
	# 
	# I'm sure this could be done more gracefully.  Feel free to
	# to tidy up the unescaping routine and submit back your code.
	# :-) Miko
	# 
	while (keys(%esc) < 4) {
		my $str = rand;
		$str =~ s|^0\.||;

		unless ($raw =~ m|$str|)
			{undef $esc{$str}}
	}
	
	($quote, $left, $right, $amp) = keys(%esc);
	
	$raw =~ s|&#34;|$quote|g;
	$raw =~ s|&#60;|$left|g;
	$raw =~ s|&#62;|$right|g;
	$raw =~ s|&#38;|$amp|g;
	# 
	# placeholders for un-escaping
	#-------------------------------------------------------------

	
	# split into tags
	$raw =~ s|^\s*\<||;
	$raw =~ s|\>$||;
	@els = split(m|\>\s*\<|, $raw);
	undef $raw; # don't need this anymore, might as well clean up now
	
	# loop through tags
	TAGLOOP:
	foreach my $el (@els) {
		# if end tag
		if ($el =~ m|^/|) {
			# if stack is down to 1 element, we're done
			(@stack == 1) && return $stack[0]->[0];
			
			pop @stack;
			next TAGLOOP;
		}
		
		# variables
		my ($type, $new, $selfender, %atts, $ref);
		
		# get type
		if ($el =~ s|^hashref\b\s*||i) {
			$type = HASHREF;
			$new = {};
			$ref = 1;
		}
		elsif ($el =~ s|^arrayref\b\s*||i) {
			$type = ARRREF;
			$new = [];
			$ref = 1;
		}
		elsif ($el =~ s|^scalarref\b\s*||i) {
			$type = SCAREF;
			$ref = 1;
		}
		elsif ($el =~ s|^scalar\b\s*||i) {
			$type = SCALAR;
		}
		elsif ( (! $firstdone) && ($el =~ s|^taxi\b\s*||i) ) {
			# do nothing
		}

		# else I don't know this tag
		else
			{croak "do not understand tag: $el"}

		# self-ender?
		$el =~ s|\s*$||;
		$selfender = $el =~ s|\s*/$||;
		
		
		#-------------------------------------------------------------
		# parse into hash
		# 
		$el =~ s|\s*\<$||;
		$el =~ s|(\S+)\s*\=\s*"([^"]*)"\s*|\L$1\E\<$2\<|g;
		
		# TESTING
		#print "[$el]\n";

		%atts = grep {
			s|$quote|"|g;
			s|$left|<|g;
			s|$right|>|g;
			s|$amp|&|g;
			1;
			} split('<', $el);
		# 
		# parse into hash
		#-------------------------------------------------------------
		
		
		# if first tag
		if (! $firstdone) {
			# version check
			unless (exists $Data::Taxi::HANDLE_FORMATS{$atts{'ver'}})
				{croak "Do not know this format version: $atts{'ver'}"}
			
			$firstdone = 1;
			next TAGLOOP;
		}

		
		# if ID, and ID already exists, that's the new object
		if (  defined($atts{'id'})  &&  $ids{$atts{'id'}}   )
			{$new = $ids{$atts{'id'}} }
		elsif (defined $atts{'class'})
			{bless $new, $atts{'class'}}
		
		# if scalar
		elsif ($type == SCALAR)
			{$new = $atts{'value'}}
		
		# if scalar reference
		elsif ($type == SCAREF) {
			my $val;
			$new = \$val;
		}
		
		# if reference
		if ($ref)
			{$ids{$atts{'id'}} = $new}
		
		if ( @stack ) {
			# get prev and prevtype
			my($prev, $prevtype) = @{$stack[$#stack]};
			
			# if prevtype is array, push into prev
			if ($prevtype == HASHREF)
				{$prev->{$atts{'name'}} = $new}
			
			# if prevtype is array, push into prev
			elsif ($prevtype == ARRREF)
				{push @{$prev}, $new}
			
			# else set scalar reference
			else
				{${$prev} = $new}
		}

		# if this is a selfender
		elsif ($selfender)
			{return $new}
		
		# if ! self ender and current is hash or arr
		if (  (! $selfender)  &&  ( ($type == HASHREF) || ($type == ARRREF) || ($type == SCAREF) )  )
			{push @stack, [$new, $type]}
	}
	
	# if we get this far, that's an error
	die 'invalid FreezDry data format';
}
# 
# thaw data
#-----------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------
# mlesc
# 
# Private sub. Escapes &, <, >, and " so that they don't mess up my parser.
# 
sub mlesc {
        my ($rv) = @_;
        return '' unless defined($rv);
        $rv =~ s|&|&#38;|g;
        $rv =~ s|"|&#34;|g;
        $rv =~ s|<|&#60;|g;
        $rv =~ s|>|&#62;|g;
        return $rv;
}
# 
# mlesc
#-----------------------------------------------------------------------------------


# return true
1;

__END__


=head1 Is Taxi data XML?

Although Taxi's data format is XML-ish, it's not fully compliant 
to XML in all regards.  For now, Taxi only promises that it can input
its own output.  The reason I didn't go for full XML compliance is that I
wanted to keep Taxi as light as possible while achieving its main goal
in life: pure-perl serialization.  XML compliance is not part of that goal.
If you want to help make Taxi fully XML compliant w/o making it bloated,
that's cool, drop me an email and we can work together.


=head1 TODO

=over

=item See how people like it

=back

=head1 License



=head1 TERMS AND CONDITIONS

Copyright (c) 2002 by Miko O'Sullivan.  All rights reserved.  This program is 
free software; you can redistribute it and/or modify it under the same terms 
as Perl itself. This software comes with B<NO WARRANTY> of any kind.


=head1 AUTHOR

Miko O'Sullivan
F<miko@idocs.com>


=head1 VERSION

 Version 0.90    June 15, 2002

=cut
