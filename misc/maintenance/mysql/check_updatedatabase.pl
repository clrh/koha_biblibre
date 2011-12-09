#!/usr/bin/perl

# This script parse an updatedatabase.pl file for SQL queries
# and try to check in database if those queries have been executed
# It supports actually only simple SQL queries like:
#   CREATE TABLE tbl_name   -- Check if table tbl_name exists
#   ALTER TABLE tbl_name ADD col_name  -- Check if tbl_name.col_name exists
#   INSERT INTO systempreferences VALUES(...) -- Check if syspref exists
#   INSERT INTO permissions VALUES(...) -- Check if permission exists
#
# To run it, type:
#   ./check_updatedatabase.pl -u db_user -p db_pass -d db_name -f updatedatabase.pl
# You can use --minversion 3.02.00.000 to check only since this version number

use Modern::Perl;
use Getopt::Long;

my $usage = <<EOF;
check_updatedatabase.pl
    -h|--help           Print this help and exit;
    -u|--user           Database username
    -p|--pass           Database password
    -d|--dbname         Database name
    -c|--context        Use C4::Context to handle database connection. In this
                        case, --user, --pass and --dbname options are ignored.
    -v|--verbose        Print some debug informations
    -s|--show-sql       Show SQL query when an inconsistency is found.
    -f|--file           updatedatabase.pl path
    -m|--minversion     Version where to start checking
EOF

my $help = 0;
my $use_context = 0;
my $verbose = 0;
my $show_sql = 0;
my $db_user = "";
my $db_pass = "";
my $db_name = "";
my $minversion = "";

my $updatedbfile = "installer/data/mysql/updatedatabase.pl";

GetOptions( "help" => \$help,
            "context" => \$use_context,
            "verbose" => \$verbose,
            "show-sql" => \$show_sql,
            "user=s" => \$db_user,
            "pass=s" => \$db_pass,
            "dbname=s" => \$db_name,
            "file=s" => \$updatedbfile,
            "minversion=s" => \$minversion,
) or die $usage;

if($help) {
    print $usage;
    exit 0;
}

open FH, "<$updatedbfile" or die "Can't open file $updatedbfile: $!";

my $dbh;
if($use_context) {
    require C4::Context;
    import C4::Context;
    $dbh = C4::Context->dbh;
} else {
    $db_name or die "No database specified";
    require DBI;
    import DBI;
    $dbh = DBI->connect("dbi:mysql:$db_name", $db_user, $db_pass);
}
$dbh or die "Can't connect to database";

my $sth = $dbh->prepare("SHOW TABLES");
$sth->execute();
my @tables;
while(my ($table) = $sth->fetchrow_array){
    push @tables, $table;
}

my $start_checking = ($minversion) ? 0 : 1;
my $exit_code = 0;
my $version;
my $sep = $/;
$/ = ";";
while (my $line = <FH>) {
    my $sql;
    $line =~ s/\n//g;
    if(not $start_checking and $line =~ "DBversion = \"(.*?)\""
      and TransformToNum($1) >= TransformToNum($minversion))
    {
        $start_checking = 1;
    }
    if($start_checking) {
        if($line =~ /sub DropAllForeignKeys/) {
            last;
        }
        # Retrieve version number
        if($line =~ /DBversion = "(.*?)"/) {
            $version = $1;
            $verbose and say "VERSION: $version";
        }
        # Retrieve SQL query
        elsif($line =~ /dbh->do\("(.*?)[;"]/) {
            $sql = $1;
        }
        elsif($line =~ /dbh->do\(q?q\{(.*?)[;\}]/) {
            $sql = $1;
        }
        $verbose and say "SQL: $sql" if $sql;

        # Parse SQL query and check consistency with database
        if($sql) {
            if($sql =~ /CREATE TABLE(?:.*?)? `(\w+)`/) {
                my $table_name = $1;
                if(!grep {/$table_name/} @tables) {
                    say "$version: Table $table_name does not exist";
                    say "SQL: $sql\n" if $show_sql;
                    $exit_code = 1;
                }
            }
            elsif ($sql =~ /ALTER TABLE *`?(\w+)`? *ADD *(?:COLUMN)? `?(\w+)`?/) {
                my $table_name = $1;
                my $column_name = $2;
                next if $column_name =~ /(UNIQUE|CONSTRAINT|INDEX|KEY|FOREIGN)/;
                if(not grep {/$table_name/} @tables) {
                    say "$version: Table $table_name does not exist";
                    say "SQL: $sql\n" if $show_sql;
                    $exit_code = 1;
                }
                else {
                    my $sth = $dbh->prepare("DESC $table_name $column_name");
                    my $rv = $sth->execute();
                    if($rv == 0) {
                        say "$version: Field $table_name.$column_name does not exist";
                        say "SQL: $sql\n" if $show_sql;
                        $exit_code = 1;
                    }
                }
            }
            elsif ($sql =~ /INSERT(?: IGNORE)? INTO `?(\w+)`?.*?VALUES *\((.*?)\)/) {
                my $table_name = $1;
                my @values = split /,/, $2;
                s/^ *'// foreach @values;
                s/' *$// foreach @values;
                #say "$version: Insert in $table_name: ". join ",", @values;
                if($table_name =~ /systempreferences/) {
                    my $syspref = $values[0];
                    my $sth = $dbh->prepare("SELECT COUNT(*) FROM systempreferences WHERE variable = ?");
                    $sth->execute($syspref);
                    if( (my $count = $sth->fetchrow_array) == 0) {
                        say "$version: Syspref $syspref does not exist";
                        say "SQL: $sql\n" if $show_sql;
                        $exit_code = 1;
                    }
                }
                elsif($table_name =~ /permissions/){
                    my $module_bit = $values[0];
                    my $code = $values[1];
                    my $sth = $dbh->prepare("SELECT COUNT(*) FROM permissions WHERE module_bit = ? AND code = ?");
                    $sth->execute($module_bit, $code);
                    if( (my $count = $sth->fetchrow_array) == 0) {
                        say "$version: Permission $code does not exist";
                        say "SQL: $sql\n" if $show_sql;
                        $exit_code = 1;
                    }
                }
            }
        }
    }
}
$/ = $sep;
close FH;
exit $exit_code;

sub TransformToNum {
    my $version = shift;

    # remove the 3 last . to have a Perl number
    $version =~ s/(.*\..*)\.(.*)\.(.*)/$1$2$3/;
    return $version;
}
