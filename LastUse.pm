package Tie::Cache::InMemory::LastUse;

require 5.00502;

use Carp::Assert;
#use base qw(Tie::Cache::LastUse Tie::Cache::InMemory);
use vars qw($VERSION);
BEGIN { 
    $VERSION = 0.02;
}

use constant SUCCESS => 1;
use constant FAILURE => 0;

# Node members.
use enum qw(KEY VALUE PREV NEXT);

=head1 NAME

Tie::Cache::InMemory::LastUse - An in memory version of Tie::Cache::LastUse


=head1 SYNOPSIS

	tie %cache, 'Tie::Cache::InMemory::LastUse', 500;
	tie %cache, 'Tie::Cache::InMemory::LastUse', '400k'; #UNIMPLEMENTED

# Otherwise exactly like Tie::Cache.


=head1 DESCRIPTION

This is an implementation of a last-use cache keeping the cache in RAM
rather than on disk.  See Tie::Cache::LastUse for details.

NOTE:  When the cache size is limited by the size of the data, this module
does uses the size of the data entered into the cache.  The cache data
structure may (will) be larger than the cache size.  Such is Perl.

=cut

sub TIEHASH {
	my($class, $max_size) = @_;
	my $self = {};
	
	bless $self, $class;
	
	$self->_init;
	$self->{max_size} = $max_size;

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
	assert(defined $last_node);
	return defined $last_node ? $last_node->[PREV][KEY]
							  : undef;
}

# The chain must be broken.
sub DESTROY  {
	my($self) = shift;
	
	for(my $node = $self->{freshest}; defined $node; ) {
		my $prev_node = $node->[PREV];
		$node->[PREV] = undef;
		$node->[NEXT] = undef;
		$node = $prev_node;
	}
	
	$self->_init;
	
	return SUCCESS;
}

sub _init {
	my($self) = shift;
	
	$self->{cache} = undef;
	$self->{freshest} = undef;
	$self->{stinkiest}   = undef;
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
	
	# Pull the $node out of its position.
	$self->_yank($node);

	# On the off chance that we're about to promote the stinkiest node, 
	# make sure the stinkiest pointer is updated.
	if( $self->{stinkiest} == $node ) {
		assert(not defined $node->[PREV]);
		$self->{stinkiest} = $node->[NEXT];
	}
	
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
		assert(!defined $rotton->[PREV]);
		my $new_stink = $rotten->[NEXT];
		
		$rotten->[NEXT]    = undef;
		$new_stink->[PREV] = undef;
		
		$self->{stinkiest} = $new_stink;
	}
	
	return SUCCESS;
}

=pod

=head1 FUTURE

Should eventually allow the cache to be in shared memory.

Max size by memory use unimplemented.

=head1 AUTHOR

Michael G Schwern <schwern@pobox.com>


=head1 SEE ALSO

Tie::Cache::LastUse, Tie::Cache::InMemory

=cut

1;
