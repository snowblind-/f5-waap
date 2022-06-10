when HTTP_REQUEST priority 900 {
  # Disable the stream filter for all requests
  STREAM::disable

  # LTM does not uncompress response content, so if the webserver has compression enabled
  # we must prevent the server from send us a compressed response by changing the request
  # header that indicates client support for compression (on our LTM client-side we can re-
  # apply compression before the response goes across the Internet)
  # Check if response type is text
  HTTP::header remove "Accept-Encoding"
  log local0. "Removed Accept-Encoding"

  set httppath [HTTP::path]
  set httphost [HTTP::host]

}

when HTTP_RESPONSE {
  # Check if response type is text
  if {[HTTP::header value Content-Type] starts_with "text"} {

    set protectedDomain $httphost

    if { $protectedDomain contains "access.udf.f5.com" } {
      set protectedDomain "access.udf.f5.com"
    }

    log local0.info "For $httppath protectedDomain: $protectedDomain"

    # get the JS from the Datagroup
    set csdjs [class match -value $protectedDomain equals client_side_defense_js]


    # NOTE: this is to add some SAMPLE maliciousJS to your site.  If you're building
    # something for a production deployment, leave this out
    # and also remove the "$malisiousjs" from the STREAM::expression
    # ie the line below should be only
    # STREAM::expression "@<head>@<head>$csdjs

    set maliciousjs {<script>(function(){
      var s = document.createElement('script');
      var domains =
      ["ganalitics.com",
      "gstatcs.com",
      "webfaset.com",
      "fountm.online",
      "munchkin.marketo.net/munchkin-beta.js",
      "pixupjqes.tech",
      "jqwereid.online",
      "proteafinance.com/wp-includes/js/jquery/jquery.js?ver=1.12.4",
      "ff5.com",
      "f5analytics.com",
      "mktg.tags.f5.com/main/prod/utag.sync.js",
      "f5.analy.tics.com"];
      for (var i = 0; i < domains.length; ++i){
        s.src = 'https://' + domains[i];
      }
      })();</script>}

      set maliciousbody { onload="addjs();</script>"}

      if {$csdjs equals "<REPLACEME>"} {
        log local0.err "Please update your Data Group with the correct JS"
      } else {
        log local0. "Searching for <head>"
        set expression1 "@<head>@<head>$csdjs$maliciousjs@"

        # For non-demo setups, remove the following line and remove $expression2 from the 
        # STREAM::express line
        set expression2 "@<body@<body$maliciousbody@"
        STREAM::expression "$expression1 $expression2"

        # Enable the stream filter for this response only
        STREAM::enable

      }
    }
  }


  when STREAM_MATCHED {
    log local0.info "\[$httppath\] CSD successfully inserted"
  }