# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)
use strict;

use vars qw($Total_tests);

my $loaded;
my $test_num = 1;
BEGIN { $| = 1; $^W = 1; }
END {print "not ok $test_num\n" unless $loaded;}
print "1..$Total_tests\n";
use Tie::Cache::LRU;
$loaded = 1;
ok(1, 'compile');
######################### End of black magic.

# Utility testing functions
sub ok {
    my($test, $name) = @_;
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


BEGIN { $Total_tests = 29 }

my %cache;
my $tied = tie %cache, 'Tie::Cache::LRU', 5;
ok(defined $tied, 'tie'); # 2


#use Devel::Leak;

# Begin watching for leaks.
#my $handle;
#my $leak_count = Devel::Leak::NoteSV($handle);


{

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


# Test accessing the sizes.
my $cache = tied %cache;
ok( $cache->curr_size == 5,                    'curr_size()' );
ok( $cache->max_size  == 5,                    'max_size()'  );

# Test lowering the max_size.
@keys = keys %cache;

$cache->max_size(2);
ok( $cache->curr_size == 2 );
ok( keys %cache == 2 );
ok( eqarray( [@keys[0..1]], [keys %cache] ) );


# Test raising the max_size.
$cache->max_size(10);
ok( $cache->curr_size == 2 );
for my $num (21..28) { $cache{$num} = "THIS IS REALLY OBVIOUS:  $num" }
ok( $cache->curr_size == 10 );
ok( eqarray( [@keys[0..1]], [(keys %cache)[-2,-1]] ) );

%cache = ();
ok( $cache->curr_size == 0 );
ok( keys   %cache     == 0 );
ok( values %cache     == 0 );
ok( $cache->max_size == 10 );

}

#Devel::Leak::CheckSV($handle);


# Make sure an empty cache will work.
my %null_cache;
$tied = tie %null_cache, 'Tie::Cache::LRU', 0;
ok(defined $tied, 'tie() null cache');

$null_cache{foo} = "bar";
ok(!exists $null_cache{foo},    'basic null cache exists()' );
ok( $tied->curr_size == 0,      'curr_size() null cache' );
ok( keys   %null_cache == 0,    'keys() null cache' );
ok( values %null_cache == 0,    'values() null cache' );
ok( $tied->max_size == 0,      'max_size() null cache' );
