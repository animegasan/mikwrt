<% include("cbi/map") %>
<script type="text/javascript">//<![CDATA[
XHR.poll(3, '<%=url([[admin]], [[services]], [[AdGuardHome]], [[status]])%>', null,
	function(x, data) {
		var tb = document.getElementById('AdGuardHome_status_service');
		if (data && tb) {
			if (data.running) {
				tb.innerHTML = '<b style=color:green><%:Running%></b>';
			} else {
				tb.innerHTML = '<b style=color:red><%:Stopped%></b>';
			}
		}
		var tb = document.getElementById('AdGuardHome_status_redirect');
                if (data && tb) {
                        if (data.redirect) {
                                tb.innerHTML = '<b style=color:green><%:Running%></b>';
                        } else {
                                tb.innerHTML = '<b style=color:red><%:Stopped%></b>';
                        }
                }
	}
);
//]]>
</script>
