# NAME

Dagoba - A quick-and-dirty port of Dagoba In-Memory Graph Database

# SYNOPSIS

    use Dagoba;

    my $dag = Dagoba->from_fam("example.fam");

    say "G->PARENTS: @{[ map { $_->{'id'} } $dag->v('G')->parents->unique->run ]}";
    say "PARENTS(G): @{[ map { $_->{'id'} } $dag->parents('G') ]}";
    say "G->ID:      @{[ $dag->v('G')->parents->unique->prop('id')->run ]}";
    print "\n";

    say "G->GRANDPS: @{[ map { $_->{'id'} } $dag->v('G')->parents->parents->unique->run ]}";
    say "G->GRANDPS: @{[ map { $_->{'id'} } $dag->v('G')->grandparents->unique->run ]}";
    say "GRANDPS(G): @{[ map { $_->{'id'} } $dag->grandparents('G') ]}";
    print "\n";

    say "SIBLINGS(C): @{[ map { $_->{'id'} } $dag->v('c')->as('me')->parents->children->except('me')->unique->run ]}";
    say "SIBLINGS(C): @{[ map { $_->{'id'} } $dag->v('c')->siblings->run ]}";
    say "SIBLINGS(C): @{[ map { $_->{'id'} } $dag->siblings('c') ]}";
    print "\n";

    say "G->COUSINS: @{[ map { $_->{'id'} } $dag->v('G')->parents->as('folks')->parents->children->except('folks')->children->unique->run ]}";
    say "G->COUSINS: @{[ map { $_->{'id'} } $dag->v('G')->parents->siblings->children->unique->run ]}";
    say "G->COUSINS: @{[ map { $_->{'id'} } $dag->v('G')->aunts_uncles->children->unique->run ]}";
    say "G->COUSINS: @{[ map { $_->{'id'} } $dag->v('G')->cousins->unique->run ]}";
    say "COUSINS(G): @{[ map { $_->{'id'} } $dag->cousins('G') ]}";
    print "\n";

    # The "merge" pipetype only includes gremlins that are still part of the final query:
    say "PARENTS(G)    ==> @{[ map { $_->{'id'} } $dag->v('G')->parents->as('parents')->run ]}";
    say "GPARENT(G)    ==> @{[ map { $_->{'id'} } $dag->v('G')->parents->parents->as('grandparents')->run ]}";
    say "  MERGE(G)    ==> @{[ map { $_->{'id'} } $dag->v('G')->parents->as('parents')
                                                              ->parents->as('grandparents')
                                                              ->merge( 'parents', 'grandparents' )
                                                              ->unique
                                                              ->run ]}";

    # To get a true union, we need to perform multiple queries:
    say "ANCESTORS(G)  ==> @{[
        sort keys %{{
          map { $_->{'id'} => $_ }
              (
                $dag->parents('G'),
                $dag->grandparents('G'),
              )
        }}
    ]}";
    print "\n";

    # "aunts_uncles_all()" includes husbands/wives (AKA "cousins' parents")
    say "AUNT/UNCLE(G)     ==> @{[ map { $_->{'id'} } $dag->aunts_uncles('G') ]}";
    say "AUNT/UNCLE-ALL(G) ==> @{[ map { $_->{'id'} } $dag->aunts_uncles_all('G') ]}";
    print "\n";

    # "filter" lets us apply a predicate to a list of vertices
    say "ALL_PARENTS(J) ==> @{[ map { $_->{'id'} } $dag->v('f')->parents->run ]}";
    say " UC_PARENTS(J) ==> @{[ map { $_->{'id'} } $dag->v('f')->parents->filter( sub { $_[0]->{'id'} eq uc( $_[0]->{'id'} ) } )->run ]}";
    say " LC_PARENTS(J) ==> @{[ map { $_->{'id'} } $dag->v('f')->parents->filter( sub { $_[0]->{'id'} eq lc( $_[0]->{'id'} ) } )->run ]}";


# DESCRIPTION

Dagoba is a quick-and-dirty Perl port of:
https://www.aosabook.org/en/500L/dagoba-an-in-memory-graph-database.html

It includes a number of shortcuts for various relationships (cousins,
grandparents, etc.)

I mostly wrote this as an excercise to better understand the original example.


# LICENSE

The MIT License (MIT)

Copyright (c) 2014 Dabrien 'Dabe' Murphy

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


# AUTHOR

Dabrien 'Dabe' Murphy <dabe@dabe.com>
