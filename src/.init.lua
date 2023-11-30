Xml2Lua = require "xml2lua"
Handler = require "xmlhandler.tree"

local about = require "about"
local dav = require "dav"

User_Agent = string.format(
    "%s/%s; redbean/%s",
    about.NAME,
    about.VERSION,
    about.REDBEAN_VERSION
)

Root = unix.realpath(arg[1])

function OnHttpRequest()
    local method = GetMethod()
    local headers = GetHeaders()
    local body = GetBody()
    for header, value in pairs(headers) do
        Log(kLogDebug, string.format("%s: %s", header, value))
    end
    Log(kLogDebug, body)
    if method == "OPTIONS" then
        SetStatus(204)
        SetHeader("Allow", "OPTIONS, GET, HEAD, PROPFIND")
        SetHeader("DAV", "1")
        return
    end
    if method == "PROPFIND" then
        dav.handlePropfind(GetPath(), body)
        return
    end
end
