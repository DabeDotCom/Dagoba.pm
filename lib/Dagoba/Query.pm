package Dagoba::Query;
use strict;
use warnings;

sub new {
    my ( $class, $graph ) = @_;
    bless {
        graph => $graph // {},    # The Graph
        state    => [],           # State for each step
        program  => [],           # List of steps to take
        gremlins => [],           # Gremlins for each step
      },
      shift;
}

sub add {
    my ( $self, $pipetype, $args ) = @_;
    my $step = [ $pipetype, $args ];
    push @{ $self->{'program'} } => $step;

    $self;
}

sub run {
    my $self = shift;
    $self->{'program'} = Dagoba::Graph::transform( $self->{'program'} );

    my $max           = $#{ $self->{'program'} };    # Index of the Last Step in the Program
    my $maybe_gremlin = 0;                           # A Gremlin, A Signal String, or False
    my $results       = [];                          # Results For This Particular Run
    my $done          = -1;                          # Behind Which Things Have Finished
    my $pc            = $max;                        # Program Counter

    my ( $step, $state, $pipetype );

    while ( $done < $max ) {
        my $ts = $self->{'state'};

        $step     = $self->{'program'}->[$pc];                    # $step is a pair of [ $pipetype, $args ]
        $state    = ( $ts->[$pc] //= {} );                        # Step's State Must Be An Object
        $pipetype = Dagoba::Graph::get_pipetype( $step->[0] );    # A Pipetype is Just a Function

        $maybe_gremlin = $pipetype->( $self->{'graph'}, $step->[1], $maybe_gremlin, $state );

        if ( $maybe_gremlin eq 'pull' ) {
            $maybe_gremlin = 0;
            if ( $pc - 1 > $done ) {
                --$pc;
                next;

            } else {
                $done = $pc;
            }
        }

        if ( $maybe_gremlin eq 'done' ) {
            $maybe_gremlin = 0;
            $done          = $pc;
        }

        ++$pc;

        if ( $pc > $max ) {
            push @$results => $maybe_gremlin if $maybe_gremlin;
            $maybe_gremlin = 0;
            --$pc;
        }
    }

    map { $_->{'result'} // $_->{'vertex'} } @$results;
}

sub one {
    my $self = shift;

    return unless my @run = $self->run();
    warn "WARNING: @{[ ref $self ]}->one(): Multiple results found; returning first\n" if @run > 1;

    $run[0];
}

###############
#  Shortcuts  #
###############

sub siblings            { shift->as('folks')->parents->children->except('folks')->unique }
sub aunts_uncles        { shift->parents->siblings->unique }
sub aunts_uncles_all    { shift->cousins->parents->unique }
sub nieces_nephews      { shift->siblings->children->unique }
sub grandparents        { shift->parents->parents->unique }
sub grandchildren       { shift->children->children->unique }
sub great_grandparents  { shift->grandparents->parents->unique }
sub great_grandchildren { shift->grandchildren->children->unique }
sub cousins             { shift->aunts_uncles->children->unique }

1;
