# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)
use strict;

my $loaded;
my $test_num = 1;
BEGIN { $| = 1; $^W = 1; }
END {print "not ok $test_num\n" unless $loaded;}
use Tie::Cache::InMemory::LastUse;
$loaded = 1;
print "ok $test_num\n";
$test_num++;
######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):
sub ok {
	my($test, $name) = shift;
	print "not " unless $test;
	print "ok $test_num";
	print " - $name" if defined $name;
	print "\n";
	$test_num++;
}

sub eqarray  {
	my($a1, $a2) = @_;
	return 0 unless @$a1 == @$a2;
	my $ok = 1;
	for (0..$#{$a1}) { 
	    unless($a1->[$_] eq $a2->[$_]) {
		$ok = 0;
		last;
	    }
	}
	return $ok;
}

my %cache;
my $tied = tie %cache, 'Tie::Cache::InMemory::LastUse', 5;
ok(defined $tied, 'tie'); # 2

$cache{foo} = "bar";
ok($cache{foo} eq 'bar', 'basic store & fetch'); # 3

ok(exists $cache{foo}, 'basic exists'); # 4

$cache{bar} = 'yar';
$cache{car} = 'jar';
# should be car, bar, foo
my @test_order = qw(car bar foo);
my @keys = keys %cache;
ok(eqarray(\@test_order, \@keys), 'basic keys'); # 5


# Try a key reordering.
my $foo = $cache{bar};
# should be bar, car, foo
@test_order = qw(bar car foo);
@keys = keys %cache;
ok(eqarray(\@test_order, \@keys), 'basic promote'); # 6


# Try the culling.
$cache{har}  = 'mar';
$cache{bing} = 'bong';
$cache{zip}  = 'zap';
# should be zip, bing, har, bar, car
@test_order = qw(zip bing har bar car);
@keys = keys %cache;
ok(eqarray(\@test_order, \@keys), 'basic cull'); # 7


# Try deleting from the end.
delete $cache{car};
ok(eqarray([qw(zip bing har bar)], [keys %cache]), 'end delete'); # 8

# Try from the front.
delete $cache{zip};
ok(eqarray([qw(bing har bar)], [keys %cache]), 'front delete');  # 9

# Try in the middle
delete $cache{har};
ok(eqarray([qw(bing bar)], [keys %cache]), 'middle delete'); #10

# Add a bunch of stuff and make sure the index doesn't grow.
@cache{qw(1 2 3 4 5 6 7 8 9 10)} = qw(11 12 13 14 15 16 17 18 19 20);
ok(keys %{tied(%cache)->{index}} == 5);




