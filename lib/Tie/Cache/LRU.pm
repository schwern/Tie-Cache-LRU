package Tie::Cache::LRU;

use strict;

require 5.00502;

use Carp::Assert;

use vars qw($VERSION);
BEGIN { 
    $VERSION = 0.06;
}

use constant DEFAULT_MAX_SIZE => 500;

use constant SUCCESS => 1;
use constant FAILURE => 0;

# Node members.
use enum qw(KEY VALUE PREV NEXT);

=head1 NAME

Tie::Cache::LRU - A Least-Recently Used cache


=head1 SYNOPSIS

    tie %cache, 'Tie::Cache::LRU', 500;
    tie %cache, 'Tie::Cache::LRU', '400k'; #UNIMPLEMENTED

    # Use like a normal hash.
    
    $cache_obj = tied %cache;
    $current_size = $cache_obj->curr_size;
    
    $max_size = $cache_obj->max_size;
    $cache_obj->max_size($new_size);


=head1 DESCRIPTION

This is an implementation of a least-recently used (LRU) cache keeping
the cache in RAM.

A LRU cache is similar to the kind of cache used by a web browser.
New items are placed into the top of the cache.  When the cache grows
past its size limit, it throws away items off the bottom.  The trick
is that whenever an item is -accessed-, it is pulled back to the top.
The end result of all this is that items which are frequently accessed
tend to stay in the cache.



=head1 USAGE

The cache is extremely simple, is just holds a simple scalar.  If you
want to cache an object, just place it into the cache:

    $cache{$obj->id} = $obj;

This doesn't make a copy of the object, it just holds a reference to
it.  (Note: This means that your object's destructor will not be
called until it has fallen out of the cache (and all other references
to it have disappeared, of course)!)

If you want to cache an array, place a reference to it in the cache:

    $cache{$some_id} = \@array;

Or, if you're worried about the consequences of tossing around
references and want to cache a copy instead, you can do something like
this:

    $cache{$some_id} = [@array];


=head2 Tied Interface

=over 4

=item B<tie>

    tie %cache, 'Tie::Cache::LRU';
    tie %cache, 'Tie::Cache::LRU', $cache_size;

This ties a cache to %cache which will hold a maximum of $cache_size
keys.  If $cache_size is not given it uses a default value,
Tie::Cache::LRU::DEFAULT_MAX_SIZE.

If the size is set to 0, the cache is effectively turned off.  This is
useful for "removing" the cache from a program without having to make
deep alterations to the program itself, or for checking performance
differences with and without a cache.

All of the expected hash operations (exists, delete, slices, etc...) 
work on the %cache.


=cut

sub TIEHASH {
    my($class, $max_size) = @_;
    my $self = {};
    
    bless $self, $class;
    
    $max_size = DEFAULT_MAX_SIZE unless defined $max_size;

    $self->_init;
    $self->max_size($max_size);

    return $self;
}


sub FETCH {
    my($self, $key) = @_;
    
    return unless $self->EXISTS($key);
    
    my $node = $self->{index}{$key};
    $self->_promote($node);
    return $node->[VALUE];
}


sub STORE {
    my($self, $key, $value) = @_;

    if( $self->EXISTS($key) ) {
        my $node = $self->{index}{$key};
        $node->[VALUE] = $value;
        $self->_promote($node);
    }
    else {
        my $node = [];
        @{$node}[KEY, VALUE] = ($key, $value);
        
        # Make ourselves the freshest.
        if(defined $self->{freshest} ) {
            $self->{freshest}->[NEXT] = $node;
            $node->[PREV] = $self->{freshest};
        }
        else {
            assert($self->{size} == 0);
        }
        $self->{freshest} = $node;
        
        # If we're the first node, we are stinky, too.
        unless( defined $self->{stinkiest} ) {
            assert($self->{size} == 0);
            $self->{stinkiest} = $node;
        }
        $self->{size}++;
        $self->{index}{$key} = $node;
        $self->_cull;
    }
    return SUCCESS;
}


sub EXISTS {
    my($self, $key) = @_;
    
    return exists $self->{index}{$key};
}


sub CLEAR {
    my($self) = @_;
    $self->_init;
}


sub DELETE {
    my($self, $key) = @_;
    
    return unless $self->EXISTS($key);
    
    my $node = $self->{index}{$key};
    $self->{freshest}  = $node->[PREV] if $self->{freshest}  == $node;
    $self->{stinkiest} = $node->[NEXT] if $self->{stinkiest} == $node;
    $self->_yank($node);
    delete $self->{index}{$key};
    
    $self->{size}--;
    
    return SUCCESS;
}


# keys() should return most to least recent.
sub FIRSTKEY {
    my($self) = shift;
    my $first_node = $self->{freshest};
    assert($self->{size} == 0 xor defined $first_node);
    return $first_node->[KEY];
}

sub NEXTKEY  {
    my($self, $last_key) = @_;
    my $last_node = $self->{index}{$last_key};
    assert(defined $last_node) if DEBUG;

    # NEXTKEY uses PREV, yes.  We're going from newest to oldest.
    return defined $last_node->[PREV] ? $last_node->[PREV][KEY]
                              : undef;
}


sub DESTROY  {
    my($self) = shift;

    # The chain must be broken.
    $self->_init;
    
    return SUCCESS;
}

=pod

=back

=head2 Object Interface

There's a few things you just can't do through the tied interface.  To
do them, you need to get at the underlying object, which you do with
tied().

    $cache_obj = tied %cache;

And then you can call a few methods on that object:

=over 4

=item B<max_size>

  $cache_obj->max_size($size);
  $size = $cache_obj->max_size;

An accessor to alter the maximum size of the cache on the fly.

If max_size() is reset, and it is lower than the current size, the cache
is immediately truncated.

The size must be an integer greater than or equal to 0.

=cut

sub max_size {
    my($self) = shift;

    if(@_) {
        my ($new_max_size) = shift;
        assert(defined $new_max_size && $new_max_size !~ /\D/);
        $self->{max_size} = $new_max_size;

        # Immediately purge the cache if necessary.
        $self->_cull if $self->{size} > $new_max_size;

        return SUCCESS;
    }
    else {
        return $self->{max_size};
    }
}


=pod

=item B<curr_size>

  $size = $cache_obj->curr_size;

Returns the current number of items in the cache.

=cut

sub curr_size {
    my($self) = shift;

    # We brook no arguments.
    assert(!@_);

    return $self->{size};
}


sub _init {
    my($self) = shift;

    # The cache is a chain.  We must break up its structure so Perl
    # can GC it.
    while( my($key, $node) = each %{$self->{index}} ) {
        $node->[NEXT] = undef;
        $node->[PREV] = undef;
    }

    $self->{freshest}  = undef;
    $self->{stinkiest} = undef;
    $self->{index} = {};
    $self->{size} = 0;
    
    return SUCCESS;
}


sub _yank {
    my($self, $node) = @_;
    
    my $prev_node = $node->[PREV];
    my $next_node = $node->[NEXT];
    $prev_node->[NEXT] = $next_node if defined $prev_node;
    $next_node->[PREV] = $prev_node if defined $next_node;

    $node->[NEXT] = undef;
    $node->[PREV] = undef;

    return SUCCESS;
}


sub _promote {
    my($self, $node) = @_;
    
    # _promote can take a node or a key.  Get the node from the key.
    $node = $self->{index}{$node} unless ref $node;
    return unless defined $node;
    
    # Don't bother if there's only one node, or if this node is
    # already the freshest.
    return if $self->{size} == 1 or $self->{freshest} == $node;
    
    # On the off chance that we're about to promote the stinkiest node,
    # make sure the stinkiest pointer is updated.
    if( $self->{stinkiest} == $node ) {
        assert(not defined $node->[PREV]);
        $self->{stinkiest} = $node->[NEXT];
    }

    # Pull the $node out of its position.
    $self->_yank($node);
    
    # Place the $node at the head.
    my $old_head  = $self->{freshest};
    $old_head->[NEXT]  = $node;
    $node->[PREV]      = $old_head;
    $node->[NEXT]      = undef;

    $self->{freshest} = $node;
    
    
    return SUCCESS;
}


sub _cull {
    my($self) = @_;
    
    # Could do this in one step, but it makes sizing the cache by
    # memory use (not # of items) more difficult.
    my $max_size = $self->{max_size};
    for( ;$self->{size} > $max_size; $self->{size}-- ) {
        my $rotten = $self->{stinkiest};
        assert(!defined $rotten->[PREV]);
        my $new_stink = $rotten->[NEXT];
        
        $rotten->[NEXT]    = undef;
        
        # Gotta watch out for autoviv.
        $new_stink->[PREV] = undef if defined $new_stink;
        
        $self->{stinkiest} = $new_stink;
        if( $self->{freshest} eq $rotten ) {
            assert( $self->{size} == 1 ) if DEBUG;
            $self->{freshest}  = $new_stink;
        }

        delete $self->{index}{$rotten->[KEY]};
    }
    
    return SUCCESS;
}

=pod


=head1 FUTURE

Should eventually allow the cache to be in shared memory.

Max size by memory use unimplemented.

For small cache sizes, it might be more efficient to just use an array
instead of a linked list.


=head1 AUTHOR

Michael G Schwern <schwern@pobox.com> for Arena Networks


=head1 SEE ALSO

L<perl(1)>

=cut

return q|Look at me, look at me!  I'm super fast!  I'm bionic!  I'm bionic!|;
