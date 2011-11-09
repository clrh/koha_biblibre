#!/usr/bin/perl
use Modern::Perl;
use C4::Context;
use C4::AuthoritiesMarc;
use C4::Search::Query;
use C4::Search;
use C4::Charset;
use C4::Debug;

use Getopt::Long;
use YAML;
use diagnostics; 
my @matchstrings;
my ($verbose,$all,$help,$wherestring,$test);
my $result = GetOptions ("match=s"   => \@matchstrings      # string
                         , "verbose"  => \$verbose
                         , "all|a"  => \$all
                         , "test|t"  => \$test
                         , "help|h"   => \$help
                         , "where=s"   => \$wherestring
                        );  # flag

if ( $help || ! (@ARGV || $all)) {
    print_usage();
    exit 0;
}

my $dbh=C4::Context->dbh;
if (not C4::Context->preference('SearchEngine') =~/Solr/gi){
   die "This Script has only been tested on Solr";
}
C4::Context->set_preference('SearchEngine', 'SolrIndexOff');
my $merge;
my $authtypes_ref=$dbh->selectcol_arrayref( qq{SELECT authtypecode, auth_tag_to_report FROM auth_types }, { Columns=>[1,2] });
my %authtypes=@$authtypes_ref;
my %biblios;
my %authorities;
my @authtypecodes= @ARGV ;
@authtypecodes = keys %authtypes unless(@authtypecodes);
unless (@matchstrings){
    @matchstrings=(qq{at/152b##auth-ppn/009});
#    @matchstrings=(qq{at/152b##he-main/2..a##he/2..bxyzt##ppn/009});
    #@matchstrings=(qq{authtype/152b##he-main,ext/2..a##he,ext/2..bxyz});
    #@matchstrings=(qq{sn,ne,st-numeric/001##authtype/152b##he-main,ext/2..a##he,ext/2..bxyz});
}

my @attempts=prepare_matchstrings(@matchstrings);

for my $authtypecode (@authtypecodes) {
    $debug and warn $authtypecode;
    my @sqlparams;
    my $strselect
        = qq{SELECT authid, NULL FROM auth_header where authtypecode=?};
    push @sqlparams, $authtypecode;
    if ($wherestring) {
        $strselect .= " and $wherestring";
    }
    my $auth_ref
        = $dbh->selectcol_arrayref( $strselect, { Columns => [ 1, 2 ] },
        @sqlparams );
    my $auth_tag = $authtypes{$authtypecode};
    my %hash_authorities_authtypecode;
    if ($auth_ref){
        %hash_authorities_authtypecode=@$auth_ref;
        @authorities{keys %hash_authorities_authtypecode} = values %hash_authorities_authtypecode;
    }
    for my $authid ( keys %hash_authorities_authtypecode ) {

        #authority was marked as duplicate
        next if $authorities{$authid};
        my $authrecord = GetAuthority($authid);

        # next if cannot take authority
        next unless $authrecord;
        SetUTF8Flag($authrecord);
        my $success;
        for my $attempt (@attempts) {
            my $query = _build_query( $authrecord, $attempt );
            $debug and warn _build_query( $authrecord, $attempt );
            next unless $query =~ /(he|ppn)=/;
            my $stringquery = eval {
                C4::Search::Query->normalSearch($query);
            };
            $debug and warn $stringquery;
            my $results = SimpleSearch( $stringquery );
            if ( $@ || !$results ) {
                $debug and warn $@;
                $debug and warn YAML::Dump(C4::Search::Query->normalSearch($query));
                $debug and warn $auth_tag;
                next;
            }
            $debug and warn YAML::Dump($results);
            next if ( !$results or scalar( @{ $results->{items} } ) < 1 );
            my ( $recordid_to_keep, @recordids_to_merge )
                = _choose_records( $authid,
                map { $_->{values}->{recordid} } @{ $results->{items} } );
            unless ($test) {
                for my $localauthid (@recordids_to_merge) {
                    my @editedbiblios=eval {merge( $localauthid, undef, $recordid_to_keep, undef )};
                    if ($@){
                        warn "merging $localauthid into $recordid_to_keep failed :", $@;
                    }
                    for my $biblio (@editedbiblios){
                        $biblios{$biblio}=1;
                    }
                    $authorities{$localauthid}  = 2;
                }
                $authorities{$recordid_to_keep} = 1;
            }
        }
    }
}
$verbose and print scalar(grep {$authorities{$_}>0} keys %authorities), " autorités fusionnées";
C4::Context->set_preference('SearchEngine', 'Solr');
##Reindex
C4::Search::IndexRecord("biblio",[keys %biblios]);
C4::Search::IndexRecord("authority",[grep {$authorities{$_}==1} keys %authorities]);
for (grep {$authorities{$_}==2} keys %authorities){
    C4::Search::Engine::Solr->DeleteRecordIndex("authority",$_);
}
exit 1;

sub compare_arrays{
    my ($arrayref1,$arrayref2)=@_;
    return 0 if scalar(@$arrayref1)!=scalar(@$arrayref2);
    my $compare=1;
    for (my $i=0;$i<scalar(@$arrayref1);$i++){
        $compare = ($compare and ($arrayref1->[$i] eq $arrayref2->[$i])); 
    }
    return $compare;
}

sub prepare_matchstrings {
    my @structure;
    for my $matchstring (@_) {
        my @andstrings      = split /##/,$matchstring;
        my @matchelements = map {
                                my $hash;
                                @$hash{qw(index subfieldtag)}=split '/', $_; 
                                @$hash{qw(tag subfields)}=($1,[ split (//, $2) ]) if $$hash{subfieldtag}=~m/([0-9\.]{3})(.*)/;
                                delete $$hash{subfieldtag};
                                $hash
                                } @andstrings;
        push @structure , \@matchelements;
    }
    return @structure;
}

#trims the spaces before and after a string
#and normalize the number of spaces inside
sub trim{
    map{
       my $value=$_;
       $value=~s/\s+$//g;
       $value=~s/^\s+//g;
       $value=~s/\s+/ /g;
       $value;
    }@_
}

sub prepare_strings{
    my $authrecord=shift;
    my $attempt=shift;
    my @stringstosearch;
    for my $field ($authrecord->field($attempt->{tag})){
        if ($attempt->{tag} le '009'){
            if ($field->data()){
                push @stringstosearch, trim($field->data());
            }
        }
        else {
            if ($attempt->{subfields}){
                for my $subfield (@{$attempt->{subfields}}){
                    push @stringstosearch, trim($field->subfield($subfield));
                }
            }
            else {
                push @stringstosearch,  trim($field->as_string());
            }

        }
    }
    return map {
                ( $_
                ?  qq<$$attempt{'index'}=\"$_\"> 
                : () )
            }@stringstosearch;
}

sub _build_query{
    my $authrecord=shift;
    my $attempt=shift;
    if ($attempt){
        my @strings_elements=map{
                                prepare_strings($authrecord,$_);
                            }@$attempt;
        $debug and warn join " and ",@strings_elements;
        return join " and ",@strings_elements;
    }
}

=head2 _choose_records
    this function takes input of candidate record ids to merging
    and returns
        first the record to merge to
        and list of records to merge from
=cut
sub _choose_records {
    my @recordids = @_;

    my @candidate_authids= grep {_is_duplicate($recordids[0],$_)} (@recordids[1..$#recordids]);
    #See http://www.sysarch.com/Perl/sort_paper.html Schwartzian transform
    @candidate_authids= map $_->[0] => sort {$a->[1] <=> $b->[1]} map {[$_,CountUsage($_)]} ($recordids[0],@candidate_authids);
    return @candidate_authids;
}

sub _is_duplicate {
    my ( $authid1, $authid2 ) = @_;
    return 0 if ( $authid1 == $authid2 );
    my $authrecord = GetAuthority($authid1);
    my $marc       = GetAuthority($authid2);
    if (!$authrecord){
        warn "no or bad record for $authid1";
        return 0;
    }
    if (!$marc){
        warn "no or bad record for $authid2";
        return 0;
    }
    my $at1        = GetAuthTypeCode($authid1);
    if (!$at1){
        warn "no or bad authoritytypecode for $authid1";
        return 0;
    }
    my $auth_tag   = $authtypes{$at1} if (exists $authtypes{$at1});
    my $at2        = GetAuthTypeCode($authid2);
    if (!$at2){
        warn "no or bad authoritytypecode for $authid2";
        return 0;
    }
    my $auth_tag2  = $authtypes{$at2} if (exists $authtypes{$at2});
    $debug and warn YAML::Dump($authrecord);
    $debug and warn YAML::Dump($marc);
    SetUTF8Flag($authrecord);
    SetUTF8Flag($marc);
    my $certainty = 1;

    $debug and warn "_is_duplicate ($authid1, $authid2)";
    if ( $marc->field($auth_tag)
        and !( $authrecord->field($auth_tag2) ) )
    {
        $debug && warn "certainty 0 ",
            $marc->field($auth_tag)->as_string, " ",
            $authrecord->field($auth_tag2)->as_string;
        return 0;
    }
    elsif ( $authrecord->field($auth_tag)
        && !( $marc->field($auth_tag2) ) )
    {
        $debug && warn "certainty 0 ",
            $marc->field($auth_tag)->as_string, " ",
            $authrecord->field($auth_tag2)->as_string;
        return 0;
    }
    for my $subfield qw(a b c d e f g i h x y z t) {
        $debug && warn "Compare subfield $subfield";
        if (compare_arrays(
                [ trim( $marc->subfield( $auth_tag, $subfield ) ) ],
                [ trim( $authrecord->subfield( $auth_tag2, $subfield ) ) ]
            )
            )
        {
            $debug && warn "certainty 1 ",
                $marc->subfield( $auth_tag, $subfield ), " ",
                $authrecord->subfield( $auth_tag2, $subfield );
        }
        else {
            $debug && warn "certainty 0 ",
                $marc->subfield( $auth_tag, $subfield ), " ",
                $authrecord->subfield( $auth_tag2, $subfield );
            $certainty=0;
        }
    }
    return $certainty;
}


sub print_usage {
    print <<_USAGE_;
$0: deduplicate authorities

Use this batch job to remove duplicate authorities

Parameters:
    --match  <matchstring>  matchstring  
                            is composed of : index1/tagsubfield1[##index2/tagsubfield2]
                            the matching will be done with an AND between all elements of ONE matchstring
                            tagsubfield can be 123a or 123abc or 123

                            If multiple match parameters are sent, then it will try to match in the order it is provided to the script.

    --where sqlstring       limit the deduplication to SOME authorities only
    --verbose               display logs
    --all                   deduplicate all authority type

    --help or -h            show this message.

Other paramters :
   Authtypecode to deduplicate authorities on  
exemple:
    $0 --match ident/009 --match he-main,ext/200a##he,ext/200bxz NC
    
Note : If launched with DEBUG=1 it will print more messages
_USAGE_
}
