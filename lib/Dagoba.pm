package Dagoba;
use strict;
use warnings;

# See: https://www.aosabook.org/en/500L/dagoba-an-in-memory-graph-database.html

use Dagoba::Graph;
use Dagoba::Query;

sub from_fam {

    ###########################
    ###  Initialize Object  ###
    ###########################

    my $self = bless { graph => Dagoba::Graph->new(), } => shift;

    my ($fam_file) = @_;

    ##########################
    ###  Check Input File  ###
    ##########################

    die "ERROR: @{[ ref $self ]}->from_fam(\"\$fam_file\"): Missing \"\$fam_file\"\n"   unless length $fam_file;
    die "ERROR: @{[ ref $self ]}->from_fam(\"$fam_file\"): No such file or directory\n" unless -e $fam_file;
    die "ERROR: @{[ ref $self ]}->from_fam(\"$fam_file\"): Permission denied\n"         unless -r $fam_file;
    die "ERROR: @{[ ref $self ]}->from_fam(\"$fam_file\"): Is a directory\n" if -d $fam_file;

    open my $FH, '<', $fam_file or die "ERROR: @{[ ref $self ]}->from_fam(\"$fam_file\"): $!\n";
    while ( defined( my $line = <$FH> ) ) {

        ########################
        ###  Strip Comments  ###
        ########################

        $line =~ s/(?!<\\)#.*//;
        $line =~ s/^\s*(.*?)\s*$/$1/;

        ##########################
        ###  Skip Blank Lines  ###
        ##########################

        next unless length $line;

        my ( $ind, $one, $two, $err ) = split /\s+/ => $line;
        die "ERROR: @{[ ref $self ]}->from_fam(\"$fam_file\"): Invalid input (missing data) on line $.\n"
          unless length($ind) && length($one) && length($two);

        die "ERROR: @{[ ref $self ]}->from_fam(\"$fam_file\"): Invalid input (extra data) on line $.\n"
          if length($err);

        $self->{'graph'}->add_vertex( { id => $ind } ) unless $self->{'graph'}->find_vertex_by_id($ind);
        $self->{'graph'}->add_vertex( { id => $one } ) unless $self->{'graph'}->find_vertex_by_id($one);
        $self->{'graph'}->add_vertex( { id => $two } ) unless $self->{'graph'}->find_vertex_by_id($two);

        $self->{'graph'}->add_edge( { out => $ind, in => $one, label => "parent" } );
        $self->{'graph'}->add_edge( { out => $ind, in => $two, label => "parent" } );
    }
    close $FH;

    $self;
}

sub v {
    Dagoba::Query->new( shift->{'graph'} )->add( vertex => [@_] );
}

sub get { shift->v(@_)->one }

# Allow, e.g., "$dag->cousins('id')", etc.

sub AUTOLOAD {
    my $q = shift->v(@_);
    $q->can( our $AUTOLOAD =~ s/.*:://r )->($q)->run;
}

1;
