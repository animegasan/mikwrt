<% include("cbi/map") %>
<script type="text/javascript">//<![CDATA[
XHR.poll(3, '<%=url([[admin]], [[services]], [[AdGuardHome]], [[status]])%>', null,
	function(x, data) {
		var service = document.getElementById('AdGuardHome_status_service');
		var redirect = document.getElementById('AdGuardHome_status_redirect');
		if (data && service && redirect) {
			if (data.running) {
				service.innerHTML = '<b style=color:green><%:Running%></b>';
			} else {
				service.innerHTML = '<b style=color:red><%:Stopped%></b>';
			}
			if (data.redirect)
			{
				redirect.innerHTML = '<b style=color:green><%:Redirected%></b>'
			} else {
				redirect.innerHTML = '<b style=color:red><%:Stopped%></b>'	
			}
		}
	}
);
//]]>
</script>
