<!-- TMPL_IF NAME="borrowernumber" -->
<div class="patroninfo"><h5><!-- TMPL_VAR name="firstname" --> <!-- TMPL_VAR name="surname" --> (<!-- TMPL_VAR NAME="cardnumber" -->)</h5>
<!--[if IE 6]>
<style type="tex/css">img { width: expression(this.width > 140 ? 140: true);
}</style>
<![endif]-->
<script type="text/javascript">
$(document).ready(function()
{
  //hide the all of the element with class msg_body
  $("#collapsedaddress").hide();
  //toggle the componenet with class msg_body
  $("#toggleaddress").click(function()
  {
    $("#collapsedaddress").slideToggle("normal");
    $("#toggleaddress").toggleClass("toggleaddress2");
  });
});
</script>
<ul>
<!-- TMPL_IF NAME="patronimages" -->
<!-- TMPL_IF NAME="picture" -->
<li><img src="/cgi-bin/koha/members/patronimage.pl?crdnum=<!-- TMPL_VAR NAME="cardnumber" -->" id="patronimage" alt="<!-- TMPL_VAR name="firstname" --> <!-- TMPL_VAR name="surname" --> (<!-- TMPL_VAR NAME="cardnumber" -->)" border="0" style="max-width : 140px; margin: .3em 0 .3em .3em; padding: .2em; border: 1px solid #CCCCCC; width:auto !important; width:130px;" /></li>
<!-- TMPL_ELSE -->
<li><img src="/intranet-tmpl/prog/img/patron-blank.png" alt="<!-- TMPL_VAR name="firstname" --> <!-- TMPL_VAR name="surname" --> (<!-- TMPL_VAR NAME="cardnumber" -->)" border="0" style="margin: .3em 0 .3em .3em; padding: .2em; border: 1px solid #CCCCCC;" /></li>
<!-- /TMPL_IF -->
<!-- /TMPL_IF -->
    <li><!-- TMPL_VAR NAME="categoryname" --> (<!-- TMPL_VAR NAME="categorycode" -->)</li>
    <li><!-- TMPL_IF NAME="branchname" --><!-- TMPL_VAR NAME="branchname" --><!-- TMPL_ELSE --><!-- TMPL_VAR NAME="branch" --><!-- /TMPL_IF --></li>
    <!-- TMPL_LOOP NAME="extendedattributes" -->
    	<!-- TMPL_IF NAME="display_checkout" -->
    		<!-- TMPL_IF NAME="value" -->
    			<!-- TMPL_VAR NAME="description" --> : <!-- TMPL_IF NAME="value_description" --><!-- TMPL_VAR NAME="value_description" --><!-- TMPL_ELSE --><!-- TMPL_VAR NAME="value" --><!-- /TMPL_IF -->
    		<!-- /TMPL_IF -->
    	<!-- /TMPL_IF -->
    <!-- /TMPL_LOOP -->
    <li>
		<div id="collapsedaddress">
			<p>
		    <!-- TMPL_IF NAME="address"-->
		            <!-- TMPL_VAR NAME="address" -->
		    <!-- TMPL_ELSE -->
		            <span class="empty">No address stored.</span>
		    <!-- /TMPL_IF -->
		    <!-- TMPL_IF NAME="address2" -->
		        <!-- TMPL_VAR NAME="address2" -->
		    <!-- /TMPL_IF -->
		    <!-- TMPL_IF NAME="city" -->
		            <!-- TMPL_VAR NAME="city" -->
			    <!-- TMPL_VAR NAME="zipcode" -->
			    <!-- TMPL_IF NAME="country" -->, <!-- TMPL_VAR NAME="country" --><!-- /TMPL_IF -->
		    <!-- TMPL_ELSE -->
		        <span class="empty">No city stored.</span>
		    <!-- /TMPL_IF -->
		    </p>
		    <p>
		    <!--TMPL_IF NAME="phone" -->
		        <!-- TMPL_VAR NAME="phone" -->
		    <!-- TMPL_ELSE -->
		        <!--TMPL_IF NAME="mobile" -->
		            <!-- TMPL_VAR NAME="mobile" -->
		        <!-- TMPL_ELSE -->
		            <!--TMPL_IF NAME="phonepro" -->
		                <!-- TMPL_VAR NAME="phonepro" -->
		            <!-- TMPL_ELSE -->
		                <span class="empty">No phone stored.</span>    
		            <!-- /TMPL_IF -->
		        <!-- /TMPL_IF -->
		    <!-- /TMPL_IF -->
		    </p><p>
		    <!-- TMPL_IF NAME="email" -->
		        <a href="mailto:<!-- TMPL_VAR NAME="email" -->" title="<!-- TMPL_VAR NAME="email" -->"><!-- TMPL_VAR NAME="email" --></a>
		    <!-- TMPL_ELSE -->
		        <!-- TMPL_IF NAME="emailpro" -->
		            <a href="mailto:<!-- TMPL_VAR NAME="emailpro" -->" title="<!-- TMPL_VAR NAME="emailpro" -->"><!-- TMPL_VAR NAME="emailpro" --></a>
		        <!-- TMPL_ELSE -->
		            <span class="empty">No email stored.</span>
		        <!-- /TMPL_IF -->
		    <!-- /TMPL_IF -->
		    </p>
		</div>
		<a id="toggleaddress" class="toggleaddress">View/Hide address</a>
    </li>
</ul>
</div>
<div id="menu">
<ul>
	<!-- TMPL_IF NAME="circview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/circ/circulation.pl?borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->">Check Out</a></li>
	<!-- TMPL_IF NAME="CAN_user_borrowers" -->
	<!-- TMPL_IF NAME="detailview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/members/moremember.pl?borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->">Details</a></li>
	<!-- /TMPL_IF -->
	 <!-- TMPL_IF NAME="CAN_user_updatecharges" -->
	<!-- TMPL_IF NAME="finesview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/members/boraccount.pl?borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->">Fines</a></li>
	<!-- /TMPL_IF -->
	<!-- TMPL_IF NAME="intranetreadinghistory" --><!-- TMPL_IF NAME="readingrecordview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/members/readingrec.pl?borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->">Circulation History</a></li><!-- /TMPL_IF -->
	<!-- TMPL_IF NAME="CAN_user_circulate_view_borrowers_logs"--><!-- TMPL_IF NAME="logview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/tools/viewlog.pl?do_it=1&amp;modules=MEMBERS&amp;modules=circulation&amp;object=<!-- TMPL_VAR NAME="borrowernumber" -->&amp;src=circ">Modification Log</a></li><!-- /TMPL_IF -->
     <!-- TMPL_IF NAME="messagingview" --><li class="active"><!-- TMPL_ELSE --><li><!-- /TMPL_IF --><a href="/cgi-bin/koha/members/messaging.pl?borrowernumber=<!-- TMPL_VAR NAME="borrowernumber" -->">Messaging</a></li>
</ul></div>

