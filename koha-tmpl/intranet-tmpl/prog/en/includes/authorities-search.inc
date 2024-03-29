<h1 id="logo"><a href="/cgi-bin/koha/mainpage.pl"><!-- TMPL_VAR NAME="LibraryName" --></a></h1>
<!-- Begin Authorities Resident Search Box -->
<div id="header_search" class="residentsearch">
    <div id="authority_search" class="residentsearch">
    <p class="tip">Enter authority heading ($a):</p>
    <form action="/cgi-bin/koha/authorities/authorities-home.pl" method="get">
        <input type="hidden" name="op" value="do_search" />
        <input type="hidden" name="searchtype" value="authority_search" />

        <select name="authtypecode">
            <option value="">All Authority Types</option>
        <!-- TMPL_LOOP NAME="authtypesloop" -->
            <!-- TMPL_IF name="selected" -->
            <option value="<!-- TMPL_VAR NAME="value" -->" selected="selected"><!-- TMPL_VAR NAME="authtypetext" --></option>
            <!-- TMPL_ELSE -->
            <option value="<!-- TMPL_VAR NAME="value" -->"><!-- TMPL_VAR NAME="authtypetext" --></option>
            <!-- /TMPL_IF -->
        <!-- /TMPL_LOOP -->
        </select>

        <input id="value_anywhere" type="text" name="value" value="<!-- TMPL_VAR NAME="value" -->" />
        <select name="orderby">
            <option value="score desc">Relevance</option>
            <option value="<!-- TMPL_VAR NAME='name_index_name' --> asc" selected="selected">Name asc</option>
            <option value="<!-- TMPL_VAR NAME='name_index_name' --> desc">Name desc</option>
            <option value="<!-- TMPL_VAR NAME='usage_index_name' --> asc">Usage asc</option>
            <option value="<!-- TMPL_VAR NAME='usage_index_name' --> desc">Usage desc</option>
         </select>
         <input type="submit" class="submit" value="Submit" />
    </form>
    </div>

    <div id="main_heading" class="residentsearch" style="display:none;">
    <p class="tip">Enter authority heading:</p>
    <form action="/cgi-bin/koha/authorities/authorities-home.pl" method="get">
        <input type="hidden" name="op" value="do_search" />
        <input type="hidden" name="searchtype" value="main_heading" />

        <select name="authtypecode">
            <option value="">All Authority Types</option>
        <!-- TMPL_LOOP NAME="authtypesloop" -->
            <!-- TMPL_IF name="selected" -->
            <option value="<!-- TMPL_VAR NAME="value" -->" selected="selected"><!-- TMPL_VAR NAME="authtypetext" --></option>
            <!-- TMPL_ELSE -->
            <option value="<!-- TMPL_VAR NAME="value" -->"><!-- TMPL_VAR NAME="authtypetext" --></option>
            <!-- /TMPL_IF -->
        <!-- /TMPL_LOOP -->
        </select>

        <input id="value_anywhere" type="text" name="value" value="<!-- TMPL_VAR NAME="value" -->" />
        <select name="orderby">
            <option value="score desc">Relevance</option>
            <option value="<!-- TMPL_VAR NAME='name_index_name' --> asc" selected="selected">Name asc</option>
            <option value="<!-- TMPL_VAR NAME='name_index_name' --> desc">Name desc</option>
            <option value="<!-- TMPL_VAR NAME='usage_index_name' --> asc">Usage asc</option>
            <option value="<!-- TMPL_VAR NAME='usage_index_name' --> desc">Usage desc</option>
         </select>
         <input type="submit" class="submit" value="Submit" />
    </form>
    </div>

    <div id="all_headings" class="residentsearch" style="display:none;">
    <p class="tip">Enter any authority field:</p>
    <form action="/cgi-bin/koha/authorities/authorities-home.pl" method="get">
        <input type="hidden" name="op" value="do_search" />
        <input type="hidden" name="searchtype" value="all_headings" />

        <select name="authtypecode">
            <option value="">All Authority Types</option>
        <!-- TMPL_LOOP NAME="authtypesloop" -->
            <!-- TMPL_IF name="selected" -->
            <option value="<!-- TMPL_VAR NAME="value" -->" selected="selected"><!-- TMPL_VAR NAME="authtypetext" --></option>
            <!-- TMPL_ELSE -->
            <option value="<!-- TMPL_VAR NAME="value" -->"><!-- TMPL_VAR NAME="authtypetext" --></option>
            <!-- /TMPL_IF -->
        <!-- /TMPL_LOOP -->
        </select>

        <input id="value_anywhere" type="text" name="value" value="<!-- TMPL_VAR NAME="value" -->" />
        <select name="orderby">
            <option value="score desc">Relevance</option>
            <option value="<!-- TMPL_VAR NAME='name_index_name' --> asc" selected="selected">Name asc</option>
            <option value="<!-- TMPL_VAR NAME='name_index_name' --> desc">Name desc</option>
            <option value="<!-- TMPL_VAR NAME='usage_index_name' --> asc">Usage asc</option>
            <option value="<!-- TMPL_VAR NAME='usage_index_name' --> desc">Usage desc</option>
         </select>
         <input type="submit" class="submit" value="Submit" />
    </form>
    </div>

    <ul>
        <li><a href="/cgi-bin/koha/authorities/authorities-home.pl#authority_search">Search Authorities</a></li>
        <li><a href="/cgi-bin/koha/authorities/authorities-home.pl#main_heading">Search Main Heading</a></li>
        <li><a href="/cgi-bin/koha/authorities/authorities-home.pl#all_headings">Search All Headings</a></li>
    </ul>
</div>
<!-- End Authorities Resident Search Box -->
