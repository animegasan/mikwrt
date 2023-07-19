--
local NXFS = require "nixio.fs"

m = Map("AdGuardHome")
s = m:section(SimpleSection, "AdGuardHome")
m.pageaction = false
s.anonymous = true
m.template="AdGuardHome/overviews"

return m