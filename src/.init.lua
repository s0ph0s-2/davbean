Xml2Lua = require "xml2lua"
Handler = require "xmlhandler.tree"

local about = require "about"
local dav = require "dav"

ServerVersion = string.format(
    "%s/%s; redbean/%s",
    about.NAME,
    about.VERSION,
    about.REDBEAN_VERSION
)

Root = unix.realpath(arg[1])
ProgramDirectory(Root)

function OnWorkerStart()
    -- set limits on memory and cpu just in case
    -- assert(unix.setrlimit(unix.RLIMIT_RSS, 2*1024*1024))
    assert(unix.setrlimit(unix.RLIMIT_CPU, 2))
    -- we only need access to files in the provided directory
    assert(unix.unveil(Root, "r"))
    assert(unix.unveil(nil, nil))
    -- we only need minimal system calls and file reading
    assert(unix.pledge("stdio rpath", nil, unix.PLEDGE_PENALTY_RETURN_EPERM))
end

function SetCommonHeaders()
    SetHeader("Server", ServerVersion)
    SetHeader("DAV", "1")
end

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
        -- The SetHeader calls must come after SetStatus because SetStatus clears the header buffer.
        SetHeader("Allow", "OPTIONS, GET, HEAD, PROPFIND")
        SetCommonHeaders()
        Log(kLogDebug, "Sending OPTIONS answer for read-only methods")
        return
    end
    if method == "PROPFIND" then
        dav.handlePropfind(path, body)
        SetCommonHeaders()
        return
    end
    if method == "GET" or method == "HEAD" then
        Route()
        SetCommonHeaders()
        return
    end
    if method == "PROPPATCH" or method == "MKCOL" or method == "POST" or method == "DELETE" or method == "PUT" or method == "COPY" or method == "MOVE" or method == "LOCK" or method == "UNLOCK" then
        ServeError(405, "This WebDAV server is read-only")
        SetCommonHeaders()
        return
    end
end
