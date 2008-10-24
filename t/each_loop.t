#!/usr/bin/perl -w

use strict;
use Test::More tests => 2;

use Tie::Cache::LRU::Array;
use Tie::Cache::LRU::LinkedList;

my %Test_Hash = qw( a aa b bb );

for my $class (qw(Tie::Cache::LRU::Array Tie::Cache::LRU::LinkedList)) {
    my %cache;
    my $tied = tie %cache, $class, 5;

    foreach my $k (sort { $a cmp $b } keys(%Test_Hash)) {
        $cache{$k} = $Test_Hash{$k};
    }

    my @each;
    while (my($k, $v) = each(%cache)) {
        push @each, $k, $v;
    }

    note("Testing $class");
    is_deeply \@each, [b => 'bb', a => 'aa'], 'each() comes out in LRU order';
}
