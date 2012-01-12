$(document).ready(function(){
    // If we are in search.pl, we can't delete session for checkboxes
    var reg = new RegExp("opac-search.pl", "");
    if ( !location.href.match(reg) ) {
        $.session("advsearch_checkboxes", []);
    }

    $("#searchsubmit").attr("been_submitted", "");

    $("#searchsubmit").click(function() {
        if ( $(this).attr("been_submitted") ) {
            return false;
        }
        $(this).attr("been_submitted", "true");
        $(this).val(_("Please wait..."));
    } );
});
