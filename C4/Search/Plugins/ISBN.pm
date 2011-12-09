package C4::Search::Plugins::ISBN;

# Copyright (C) 2011 BibLibre
#
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
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use Business::ISBN;
use base 'Exporter';

our @EXPORT = qw/
       &ComputeValue
    /;
our $VERSION = 3.0.1;

sub ComputeValue {
    my $record = shift;
    my $mapping = shift;
    my @values = ();
    for my $tag ( keys (%$mapping) ) {
        for my $code ( @{$$mapping{$tag}} ) {
            for my $f ( $record->field($tag) ) {
                for my $sf ($f->subfield($code)){
                    my $isbn = Business::ISBN->new( $sf );
                    if($isbn) {
                        my $isbn10 = $isbn->as_isbn10->as_string;
                        my $isbn13 = $isbn->as_isbn13->as_string;
                        push @values, $isbn10;
                        push @values, $isbn13;
                        $isbn10 =~ s/-//g;
                        $isbn13 =~ s/-//g;
                        push @values, $isbn10;
                        push @values, $isbn13;
                    } else {
                        # It's not a valid ISBN but we want to index it anyway
                        my $value = $sf;
                        push @values, $value;
                        if($value =~ /-/) {
                            $value =~ s/-//g;
                            push @values, $value;
                        }
                    }
                }
            }
        }
    }
    return @values;
}

1;

