package C4::Search::Query::Solr;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

use strict;
use warnings;

use 5.10.0;

use C4::Search::Query;

=head1 NAME

C4::Search::Query::Solr

=head1 SYNOPSIS

Generate new Solr query from indexes, operands and operators

=head1 DESCRIPTION

return a Solr query

=head1 FUNCTIONS

=cut

sub buildQuery {

    my ($class, $indexes, $operands, $operators) = @_;

    my $q = '';
    my $i = 0;
    my $index_name;

    @$operands or return "*:*"; #push @$operands, "[* TO *]";

    # Foreach operands
    for my $kw (@$operands){
        $kw =~ s/(\w*\*)/\L$1\E/g; # Lower case on words with right truncation
        $kw =~ s/(\s*\w*\?+\w*\s*)/\L$1\E/g; # Lower case on words contain wildcard ?
        $kw =~ s/([^\\]):/$1\\:/g; # escape colons if not already escaped
        # First element
        if ($i == 0){
            if ( (my @x = eval {@$indexes} ) == 0 ){
                # There is no index, then query is in first operand
                $q = @$operands[0];
                last;
            }

            # Catch index name if it's not 'all_fields'
            if ( @$indexes[$i] ne 'all_fields' ) {
                $index_name = @$indexes[$i];
            }else{
                $index_name = '';
            }

            # Generate index:operand
            $q .= BuildTokenString($index_name, $kw);
            $i = $i + 1;

            next;
        }
        # And others
        $index_name = @$indexes[$i] if @$indexes[$i];
        my $operator = defined @$operators[$i-1] ? @$operators[$i-1] : 'AND';
        given ( uc ( $operator ) ) {
            when ('OR'){
                $q .= BuildTokenString($index_name, $kw, 'OR');
            }
            when ('NOT'){
                $q .= BuildTokenString($index_name, $kw, 'NOT');
            }
            default {
                $q .= BuildTokenString($index_name, $kw, 'AND');
            }
        }
        $i = $i + 1;
    }

    return $q;

}

sub BuildTokenString {
    my ($index, $string, $operator) = @_;
    my $r;

    if ($index ne 'all_fields' && $index ne ''){
        # Operand can contains an expression in brackets
        if (
            $string =~ / /
                and not ( $string =~ /^\(.*\)$/ )
                and not $string =~ /\[.*TO.*\]/ ) {
            my @dqs; #double-quoted string
            while ( $string =~ /"(?:[^"\\]++|\\.)*+"/g ) {
                push @dqs, $&;
                $string =~ s/\ *\Q$&\E\ *//; # Remove useless space before and after
            }

            my @words = defined $string ? split ' ', $string : undef;
            my $join = join qq{ AND } , map {
                my $value = $_;
                if ( $index =~ /^date_/ ) {
                    $value = C4::Search::Engine::Solr::buildDateOperand( $value );
                }
                ( $value =~ /^"/ and $value ne '""'
                        and $index ne "emallfields"
                        and $index =~ /(txt_|ste_)/ )
                    ? qq{em$index:$value}
                    : qq{$index:$value};
            } (@dqs, @words);
            $r .= qq{($join)};
        } else {
            if ( $index =~ /^date_/ ) {
                $string = C4::Search::Engine::Solr::buildDateOperand( $string );
            }

            $r = "$index:$string";
        }
    }else{
        $r = $string;
    }

    return " $operator $r" if $operator;
    return $r;
}

sub normalSearch {
    my ($class, $query) = @_;

    return "*:*" if not defined $query;

    # Particular *:* query
    if ($query  eq '*:*'){
        return $query;
    }

    $query =~ s/(\w*\*)/\L$1\E/g; # Lower case on words with right truncation
    $query =~ s/(\s*\w*\?+\w*\s*)/\L$1\E/g; # Lower case on words contain wildcard ?

    my @quotes; # Process colons in quotes
    while ( $query =~ /'(?:[^'\\]++|\\.)*+'/g ) {
        push @quotes, $&;
    }

    for ( @quotes ) {
        my $replacement = $_;
        $replacement =~ s/[^\\]\K:/\\:/g;
        $query =~ s/$_/$replacement/;
    }

    $query =~ s/ : / \\: /g; # escape colons if " : "

    my $new_query = C4::Search::Query::splitToken($query);

    $new_query =~ s/all_fields://g;

    # Upper case for operators
    $new_query =~ s/ or / OR /g;
    $new_query =~ s/ and / AND /g;
    $new_query =~ s/ not / NOT /g;

    return $new_query;
}

1;
