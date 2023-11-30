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
    local path = GetPath()
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
        dav.handlePropfind(path, body)
        return
    end
    if method == "GET" then
        SetHeader("DAV", "1")
        ServeAsset(Root .. path)
        return
    end
    if method == "PROPPATCH" or method == "MKCOL" or method == "POST" or method == "DELETE" or method == "PUT" or method == "COPY" or method == "MOVE" or method == "LOCK" or method == "UNLOCK" then
        ServeError(405, "This WebDAV server is read-only")
        return
    end
end
