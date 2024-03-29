
<h1 id="logo"><a href="/cgi-bin/koha/mainpage.pl"><!-- TMPL_VAR NAME="LibraryName" --></a></h1><!-- Begin Patrons Resident Search Box -->
<!-- TMPL_IF NAME="CAN_user_circulate" --><!-- TMPL_IF NAME="CircAutocompl" --><script type="text/javascript">
//<![CDATA[
YAHOO.util.Event.onContentReady("header_search", function() {
    new function() {
        // Define a custom formatter function
        this.fnCustomFormatter = function(oResultItem, sQuery) {
            var name        = oResultItem[0];
            var cardnumber  = oResultItem[1];
            var address     = oResultItem[2];
            var city        = oResultItem[3];
            var zip         = oResultItem[4];
            var aMarkup = [
                "<div class=\"sample-result\">",
                name,
                " (",
                cardnumber,
                ")<small> -- ",
                address,
                ", ",
                city,
                "<\/small>",
                "<\/div>"];
            return (aMarkup.join(""));
        };

        // Instantiate one XHR DataSource and define schema as an array:
        //     ["Record Delimiter",
        //     "Field Delimiter"]
        this.oACDS = new YAHOO.widget.DS_XHR("/cgi-bin/koha/circ/ysearch.pl", ["\n", "\t"]);
        this.oACDS.responseType = YAHOO.widget.DS_XHR.TYPE_FLAT;
        this.oACDS.maxCacheEntries = 60;
        this.oACDS.queryMatchSubset = true;

        // Instantiate first AutoComplete
        var myInput = document.getElementById('findborrower');
        var myContainer = document.getElementById('yborrowercontainer');
        this.oAutoComp = new YAHOO.widget.AutoComplete(myInput,myContainer,this.oACDS);
        //this.oAutoComp.delimChar = ";";
        //this.oAutoComp.queryDelay = 1;
        this.oAutoComp.formatResult = this.fnCustomFormatter;
}
});
//]]>
</script><!-- /TMPL_IF --><!-- /TMPL_IF -->
<div id="header_search">
	<div id="patron_search" class="residentsearch">
	<p class="tip">Enter patron card number or partial name:</p>
	<form action="/cgi-bin/koha/members/member.pl" method="post">
    <input id="searchmember" size="25" class="focus" name="member" type="text" value="<!--TMPL_VAR Name="member"-->"/>
	<!--TMPL_IF Name="branchloop"-->
	<span class="filteraction" id="filteraction_off"> <a href="#" onClick="$('#filters').toggle();$('.filteraction').toggle();$('#filters :input').attr('disabled','disabled');">[-]</a></span>
	<span class="filteraction" id="filteraction_on"> <a href="#" onClick="$('#filters').toggle();$('.filteraction').toggle();$('#filters :input').removeAttr('disabled');">[+]</a></span>
	<!--/TMPL_IF -->
    order by:
    <select name="orderby" id="searchorderby">
    <option value="">Surname</option>
    <option value="cardnumber,0">Cardnumber</option>
    </select>
    <input value="Search" class="submit" type="submit" />
	<!--TMPL_IF Name="branchloop"-->
	<p id="filters"> <label for="branchcode">Library: </label><select name="branchcode" id="branchcode">
        <option value="">Any</option><!-- TMPL_LOOP name="branchloop" -->
        <!-- TMPL_IF NAME="selected" -->
        <option value="<!-- TMPL_VAR name="value" -->" selected="selected"><!-- TMPL_VAR name="branchname" --></option><!-- TMPL_ELSE -->
        <option value="<!-- TMPL_VAR name="value" -->"><!-- TMPL_VAR name="branchname" --></option><!-- /TMPL_IF -->
      <!-- /TMPL_LOOP --></select>
                 <label for="categorycode">Category: </label><select name="categorycode" id="categorycode">
        <option value="">Any</option><!-- TMPL_LOOP name="categoryloop" -->
        <!-- TMPL_IF NAME="selected" -->
        <option value="<!-- TMPL_VAR name="categorycode" -->" selected="selected"><!-- TMPL_VAR name="description" --></option><!-- TMPL_ELSE -->
        <option value="<!-- TMPL_VAR name="categorycode" -->"><!-- TMPL_VAR name="description" --></option><!-- /TMPL_IF -->
      <!-- /TMPL_LOOP --></select>
	</p>
	<!--/TMPL_IF -->
    </form>
	</div>
	<!-- TMPL_IF NAME="CAN_user_circulate" -->
	<div id="circ_search" class="residentsearch" style="display:none;">
	<p class="tip">Enter patron card number or partial name:</p>
    <form action="/cgi-bin/koha/circ/circulation.pl" method="post">
    <!-- TMPL_IF NAME="CircAutocompl" -->
    <div class="autocomplete">
            <div id="borrowerautocomplete" class="autocomplete">
                <input autocomplete="off" id="findborrower" name="findborrower" type="text" />
                <div id="yborrowercontainer"></div>
                <input id="ysearchsubmit" type="submit" class="submit" value="Submit" />
                <input name="branch" value="<!-- TMPL_VAR name="branch" -->" type="hidden" />
                <input name="printer" value="" type="hidden" />
            </div>
        </div>
	<!-- TMPL_ELSE -->
            <input id="findborrower" name="findborrower" size="40" type="text" />
            <input name="branch" value="<!-- TMPL_VAR name="branch" -->" type="hidden" />
            <input name="printer" value="" type="hidden" />
            <input value="Submit" class="submit" type="submit" />
	<!-- /TMPL_IF -->
    </form>
	</div><!-- /TMPL_IF -->
	<!-- TMPL_IF NAME="CAN_user_catalogue" -->
	<div id="catalog_search" class="residentsearch" style="display:none;">
	<p class="tip">Enter search keywords:</p>
		<form action="/cgi-bin/koha/catalogue/search.pl"  method="get" id="cat-search-block">
			 <input type="text" name="q" id="search-form" size="40" value="" title="Enter the terms you wish to search for." class="form-text" />
				<input type="submit" name="op" id="opac-submit" value="Submit" class="submit" />
		</form>
	</div><!-- /TMPL_IF -->
			<ul>
			<li><a href="/cgi-bin/koha/members/members-home.pl#patron_search">Search Patrons</a></li>
			<!-- TMPL_IF NAME="CAN_user_circulate" --><li><a href="/cgi-bin/koha/circ/circulation.pl#circ_search">Check Out</a></li><!-- /TMPL_IF -->
			<!-- TMPL_IF NAME="CAN_user_catalogue" --><li><a href="/cgi-bin/koha/catalogue/search.pl#catalog_search">Search the Catalog</a></li><!-- /TMPL_IF -->
			</ul>
</div>
<script type="text/javascript">//<![CDATA[
$(document).ready(function() {

	<TMPL_IF NAME="showfilter">
	//$("#filters").toggle(); 
	$('#filters :input').attr('enabled','enabled');
    $("#filteraction_on").toggle(); 
    <TMPL_ELSE>
    $("#filters").toggle(); 
	$('#filters :input').attr('disabled','disabled');
    $("#filteraction_off").toggle(); 
    </TMPL_IF>
}); 
//]]>
</script>
<!-- End Patrons Resident Search Box -->
