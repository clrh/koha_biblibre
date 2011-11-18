#!/usr/bin/perl

use utf8;
use Modern::Perl;
use Test::More;

my $tests = 0;
plan tests => 23;

my $recordtype = "biblio";

my $recordids = [
       qq{0}, qq{1}, qq{2}, qq{3}, qq{11}, qq{12}, qq{13}, qq{21}, qq{22}, qq{23}, qq{101}, qq{102}, qq{103}, qq{111}, qq{112}, qq{211}, qq{221}, qq{222}, qq{311}, qq{321}, qq{322}, qq{323}, qq{333},
       qq{1 2}, qq{1 3}, qq{1 11}, qq{2 11}, qq{1 2 3}, qq{1 11 111}, qq{11 1 111},
       qq{2 3 11}, qq{11 2 3}
    ];

# With old RE
sub test_RE1 {
    my ( $records_indexed ) = @_;
    my @lines;
    for my $id ( @$recordids ) {
        my $line = "$recordtype $id";
        $line =~ s/^$recordtype.*\K $_// for @$records_indexed;
        push @lines, $line;
    }
    return \@lines;
}

# With new RE
sub test_RE2 {
    my ( $records_indexed ) = @_;
    my @lines;
    for my $id ( @$recordids ) {
        my $line = "$recordtype $id";
        $line =~ s/^$recordtype(?: \d*)*\K $_( |$)/$1/ for @$records_indexed;
        $line =~ s/^\S+$//;
        $line =~ s/^$recordtype\s*$//;
        push @lines, $line;
    }
    @lines = grep {!/^$/} @lines;
    return \@lines;
}

#say "=== RE1 ===";
#my $re1 = test_RE1( ["1"] );
#say join("\n", @$re1);
say "=== RE2 ===";
my @tests = (
       qq{0}, qq{1}, qq{2}, qq{3}, qq{11}, qq{12}, qq{13}, qq{21}, qq{22}, qq{23}, qq{101}, qq{102}, qq{103}, qq{111}, qq{112}, qq{211}, qq{221}, qq{222}, qq{311}, qq{321}, qq{322}, qq{323}, qq{333},
);
for my $test ( @tests ) {
    my $re2 = test_RE2( [$test] );
    #say "== $recordtype $test ==";
    my $got = grep {
    #say $_ . ":" . $_ =~ /^$recordtype\S+$/;
            ($_ =~ /^$recordtype.* $test( |$)/)
        or  ($_ =~ /^$recordtype\S/)
        or  ($_ =~ /^$recordtype$/)
        or  ($_ =~ /^$recordtype $/)
        or  ($_ =~ /  /)
        or ($_ =~ /^\S*$/)
    } @$re2;
    is( $got, 0, "test RE2 for $test" );
}

