#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
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

use strict;

#use warnings; FIXME - Bug 2505
use C4::Auth;
use CGI;
use C4::Context;

use C4::Search;
use C4::Output;

=head1

plugin_parameters : other parameters added when the plugin is called by the dopop function

=cut

sub plugin_parameters {
    my ( $dbh, $record, $tagslib, $i, $tabloop ) = @_;
    return "";
}

sub plugin_javascript {
    my ( $dbh, $record, $tagslib, $field_number, $tabloop ) = @_;
    my $function_name = $field_number;
    my $res           = "
<script>
function Focus$function_name(subfield_managed) {
return 1;
}

function Blur$function_name(subfield_managed) {
	return 1;
}

function Clic$function_name(i) {
	defaultvalue=document.getElementById(\"$field_number\").value;
	newin=window.open(\"../cataloguing/plugin_launcher.pl?plugin_name=unimarc_field_140.pl&index=$field_number&result=\"+defaultvalue,\"unimarc field 140\",'width=1000,height=575,toolbar=false,scrollbars=yes');

}
</script>
";

    return ( $function_name, $res );
}

sub plugin {
    my ($input) = @_;
    my $index   = $input->param('index');
    my $result  = $input->param('result');

    my $dbh = C4::Context->dbh;

    my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
        {   template_name   => "cataloguing/value_builder/unimarc_field_140.tmpl",
            query           => $input,
            type            => "intranet",
            authnotrequired => 0,
            flagsrequired   => { editcatalogue => '*' },
            debug           => 1,
        }
    );
    my $f1  = substr( $result, 0,  1 );
    my $f2  = substr( $result, 1,  1 );
    my $f3  = substr( $result, 2,  1 );
    my $f4  = substr( $result, 3,  1 );
    my $f5  = substr( $result, 4,  1 );
    my $f6  = substr( $result, 5,  1 );
    my $f7  = substr( $result, 6,  1 );
    my $f8  = substr( $result, 7,  1 );
    my $f9  = substr( $result, 8,  1 );
    my $f10 = substr( $result, 9,  2 );
    my $f11 = substr( $result, 11, 2 );
    my $f12 = substr( $result, 13, 2 );
    my $f13 = substr( $result, 15, 2 );
    my $f14 = substr( $result, 17, 2 );
    my $f15 = substr( $result, 19, 1 );
    my $f16 = substr( $result, 20, 1 );
    my $f17 = substr( $result, 21, 1 );
    my $f18 = substr( $result, 22, 1 );
    my $f19 = substr( $result, 23, 1 );
    my $f20 = substr( $result, 24, 1 );
    my $f21 = substr( $result, 25, 1 );

    $template->param(
        index     => $index,
        "f1$f1"   => 1,
        "f2$f2"   => 1,
        "f3$f3"   => 1,
        "f4$f4"   => 1,
        "f5$f5"   => 1,
        "f6$f6"   => 1,
        "f7$f7"   => 1,
        "f8$f8"   => 1,
        "f9$f9"   => 1,
        "f10$f10" => 1,
        "f11$f11" => 1,
        "f12$f12" => 1,
        "f13$f13" => 1,
        "f14$f14" => 1,
        "f15$f15" => 1,
        "f16$f16" => 1,
        "f17$f17" => 1,
        "f18$f18" => 1,
        "f19$f19" => 1,
        "f20$f20" => 1,
        "f21$f21" => 1
    );
    output_html_with_http_headers $input, $cookie, $template->output;
}

1;
