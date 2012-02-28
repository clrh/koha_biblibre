$(document).ready(function(){
    // If we are in search.pl, we can't delete session for checkboxes
    var reg = new RegExp("opac-search.pl", "");
    if ( !location.href.match(reg) ) {
        $.session("advsearch_checkboxes", []);
    }
});
