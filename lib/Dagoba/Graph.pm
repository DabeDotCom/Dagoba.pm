package Dagoba::Graph;
use strict;
use warnings;

use List::Util qw< reduce >;

our $Pipetypes    = {};
our $Transformers = [];

sub new {
    bless {
        edges    => [],
        vertices => [],
        index    => {},
        auto_id  => 1,
    } => shift;
}

sub find_vertex_by_id {
    my ( $self, $vertex_id ) = @_;
    die "ERROR: @{[ ref $self ]}->find_vertex_by_id(\$vertex_id): Missing \"\$vertex_id\"\n" unless $vertex_id;

    $self->{'index'}->{$vertex_id};
}

sub search_vertices {
    my ( $self, $filter ) = @_;
    grep { object_filter( $_, $filter ) } $self->{'vertices'};
}

sub add_vertex {
    my ( $self, $vertex ) = @_;
    die "ERROR: @{[ ref $self ]}->add_vertex(\$vertex): Missing \"\$vertex\"\n" unless $vertex;

    unless ( $vertex->{'id'} ) {
        $vertex->{'id'} = $self->{'auto_id'}++;
    } elsif ( $self->find_vertex_by_id( $vertex->{'id'} ) ) {
        die "ERROR: @{[ ref $self ]}->add_vertex(\@vertices): Vertex \"$vertex->{'id'}\" exists\n";
    }

    push @{ $self->{'vertices'} } => $vertex;
    $self->{'index'}->{ $vertex->{'id'} } = $vertex;
    $vertex->{'out'}                      = [];
    $vertex->{'in'}                       = [];

    $vertex->{'id'};
}

sub add_edge {
    my ( $self, $edge ) = @_;

    die "ERROR: @{[ ref $self ]}->add_edge(\$edge): Missing \"\$edge\"\n"
      unless $edge;

    die "ERROR: @{[ ref $self ]}->add_edge(\$edge): 'in' vertex ($edge->{'in'}) not found\n"
      unless $edge->{'in'} = $self->find_vertex_by_id( $edge->{'in'} );

    die "ERROR: @{[ ref $self ]}->add_edge(\$edge): 'out' vertex ($edge->{'out'}) not found\n"
      unless $edge->{'out'} = $self->find_vertex_by_id( $edge->{'out'} );

    push @{ $edge->{'out'}->{'out'} } => $edge;
    push @{ $edge->{'in'}->{'in'} }   => $edge;

    push @{ $self->{'edges'} } => $edge;
}

sub find_vertices {
    my ( $self, $args ) = @_;

    unless (@$args) {
        return @{ $self->{'vertices'} }

    } elsif ( ref $args->[0] ) {
        return $self->search_vertices( $args->[0] )

    } else {
        return $self->find_vertices_by_ids($args);
    }
}

sub find_vertices_by_ids {
    my ( $self, $ids ) = @_;

    if ( @$ids == 1 ) {
        my $maybe_vertex = $self->find_vertex_by_id( $ids->[0] );
        return $maybe_vertex ? [$maybe_vertex] : [];
    }

    grep { $_ } map { $self->find_vertex_by_id($_) } @$ids;
}

sub find_in_edges {
    my $vertex = shift;
    @{ $vertex->{'in'} };
}

sub find_out_edges {
    my $vertex = shift;
    @{ $vertex->{'out'} };
}

sub make_gremlin {
    my ( $vertex, $state ) = @_;
    scalar { vertex => $vertex, state => $state || {} };
}

sub goto_vertex {
    my ( $gremlin, $vertex ) = @_;
    make_gremlin( $vertex, $gremlin->{'state'} );
}

my $faux_pipetype = sub {
    $_[2] || 'pull';
};

sub add_pipetype {
    my ( $name, $fn ) = @_;
    $Pipetypes->{$name} = $fn;

    no strict 'refs';
    *{"Dagoba::Query::$name"} = sub {
        shift->add( $name, [@_] );
    };
}

sub get_pipetype {
    my $name = shift;

    warn "WARNING: get_pipetype($name): Unrecognized pipetype\n" unless my $pipetype = $Pipetypes->{$name};
    $pipetype // $faux_pipetype;
}

add_pipetype(
    vertex => sub {
        my ( $graph, $args, $gremlin, $state ) = @_;
        $state->{'vertices'} //= $graph->find_vertices($args);

        return 'done' unless @{ $state->{'vertices'} };

        # OPT: REQUIRES VERTEX CLONING GREMLINS FROM AS/BACK QUERIES
        make_gremlin( pop( @{ $state->{'vertices'} } ), ( $gremlin || {} )->{'state'} );
    }
);

sub filter_edges {
    my $filter = shift;

    sub {
        my $edge = shift;

        # No Filter: Everything Is Valid
        return 1 unless $filter;

        # String Filter: Label Must Match
        return $edge->{'label'} eq $filter unless ref $filter;

        # Array Filter: Must Contain Label
        return !!grep { $_ eq $edge->{'label'} } @$filter if ref $filter eq 'ARRAY';

        # Object Filter: Check Edge Keys
        return object_filter( $edge, $filter ) if ref $filter eq 'HASH';

        die "ERROR: Unknown \$filter Type (@{[ ref $filter ]}) -- $filter\n";
    };
}

sub object_filter {
    my ( $item, $filter ) = @_;
    !grep { $item->{$_} ne $filter->{$_} } keys %$filter;
}

my $simple_traversal = sub {
    my $dir = shift;

    sub {
        my ( $graph, $args, $gremlin, $state ) = @_;
        $state //= {};
        $state->{'edges'} //= [];

        return 'pull' unless $gremlin || @{ $state->{'edges'} };

        unless ( @{ $state->{'edges'} } ) {
            $state->{'gremlin'} = $gremlin;
            $state->{'edges'} =
              [ grep { filter_edges( $args->[0] )->($_) } $graph->can("find_${dir}_edges")->( $gremlin->{'vertex'} ) ];
        }

        return 'pull' unless @{ $state->{'edges'} };

        return goto_vertex( $state->{'gremlin'}, pop( $state->{'edges'} )->{ $dir eq 'out' ? 'in' : 'out' } );
    };
};

add_pipetype( in  => $simple_traversal->('in') );
add_pipetype( out => $simple_traversal->('out') );

add_pipetype(
    filter => sub {
        my ( $graph, $args, $gremlin, $state ) = @_;
        return 'pull' unless $gremlin;

        if ( ref( $args->[0] ) eq 'HASH' ) {
            return object_filter( $gremlin->{'vertex'}, $args->[0] ) ? $gremlin : 'pull';

        } elsif ( ref( $args->[0] ) eq 'CODE' ) {
            return $args->[0]->( $gremlin->{'vertex'}, $gremlin ) ? $gremlin : 'pull';

        } else {
            warn "WARNING: filter: Arg \"$args->[0]\" != HASH|CODE\n";
            return $gremlin;
        }
    }
);

add_pipetype(
    take => sub {
        my ( $graph, $args, $gremlin, $state ) = @_;
        $state->{'taken'} ||= 0;

        if ( $state->{'taken'} == $args->[0] ) {
            $state->{'taken'} = 0;
            return 'done';
        }

        return 'pull' unless $gremlin;

        ++$state->{'taken'};
        $gremlin;
    }
);

add_pipetype(
    as => sub {
        my ( $graph, $args, $gremlin, $state ) = @_;
        return 'pull' unless $gremlin;

        $gremlin->{'state'}->{'as'} //= {};
        $gremlin->{'state'}->{'as'}->{ $args->[0] } = $gremlin->{'vertex'};
        $gremlin;
    }
);

add_pipetype(
    unique => sub {
        my ( $graph, $args, $gremlin, $state ) = @_;
        return 'pull' unless $gremlin;

        return 'pull' if $state->{ $gremlin->{'vertex'}->{'id'} };
        $state->{ $gremlin->{'vertex'}->{'id'} } = 1;
        $gremlin;
    }
);

add_pipetype(
    prop => sub {
        my ( $graph, $args, $gremlin, $state ) = @_;
        return 'pull' unless $gremlin;

        $gremlin->{'result'} = $gremlin->{'vertex'}->{ $args->[0] };
        defined $gremlin->{'result'} ? $gremlin : '';
    }
);

### $graph->v('Thor')->out->as('parent')->out->as('grandparent')
###                  ->merge(  'parent',          'grandparent')
###                  ->run;
###
### NOTE: Only gremlins that make it to this pipe are included in the 'merge' pipetype...
### If Thor's mother's parents aren't in the graph, Thor's mother won't be listed, either.

add_pipetype(
    merge => sub {
        my ( $graph, $args, $gremlin, $state ) = @_;
        $state //= {};
        $state->{'vertices'} //= [];

        return 'pull' unless $gremlin || @{ $state->{'vertices'} };

        unless ( @{ $state->{'vertices'} } ) {
            my $obj = ( $gremlin->{'state'} || {} )->{'as'} || {};
            $state->{'vertices'} = [ grep { $_ } map { $obj->{$_} } @{ $args // [] } ];
        }

        return 'pull' unless @{ $state->{'vertices'} };

        make_gremlin( pop( @{ $state->{'vertices'} } ), ( $gremlin || {} )->{'state'} );
    }
);

add_pipetype(
    except => sub {
        my ( $graph, $args, $gremlin, $state ) = @_;

        if ( !$gremlin or $gremlin->{'vertex'} eq $gremlin->{'state'}->{'as'}->{ $args->[0] } ) {
            return 'pull';

        } else {
            return $gremlin;
        }
    }
);

add_pipetype(
    back => sub {
        my ( $graph, $args, $gremlin, $state ) = @_;
        return 'pull' unless $gremlin;

        goto_vertex( $gremlin, $gremlin->{'state'}->{'as'}->{ $args->[0] } );
    }
);

sub transform {
    my $program = shift;
    reduce { $b->{'fn'}->($a) } $program, @$Transformers;
}

sub add_transformer {
    my ( $fn, $priority ) = @_;

    die "ERROR: Invalid Transformer Function \"$fn\"\n" unless ref($fn) eq 'CODE';

    my $i;
    for ( $i = 0 ; $i < @$Transformers ; $i++ ) {
        last if $priority > $Transformers->[$i];
    }

    splice( @$Transformers, $i, 0, { priority => $priority, fn => $fn } );
}

sub extend {
    reduce {
        push( @$a, $b ) unless grep { $_ eq $b } @{ $_[0] };
        $a;
    }
    @{ [ $_[0] ] }, @{ $_[1] || [] };
}

sub add_alias {
    my ( $newName, $oldName, $defaults ) = @_;

    add_transformer(
        sub {
            my $program = shift;
            [ map { $_->[0] eq $newName ? [ $oldName, extend( $_->[1], $defaults ) ] : $_ } @$program ];
        },
        100
    );

    add_pipetype( $newName, sub { } );
}

add_alias( parents  => 'out', ['parent'] );
add_alias( children => 'in',  ['parent'] );

1;
