string.startswith = function(s, prefix)
    assert(s)
    assert(prefix)
    local prefixLen = #prefix
    return string.sub(s, 1, prefixLen) == prefix
end
--- Identify and remove DAV namespace prefixes on element names.
--- This function reads the `_attr` sub-table to find `xmlns` namespace
--- declarations. If any declared namespace is `DAV:`, that namespace's prefix
--- is removed from the tag name and the namespace attribute is removed.  If
--- this removal results in an empty _attr table, that is also removed.
--- @param t (table) A table full of XML-equivalent data, to be modified in-place.
--- @param knownNamespaces (string[]?) Any namespace prefixes that are already known to be for DAV.
local function simplifyDavNamespace(t, knownNamespaces)
    if not knownNamespaces then
        knownNamespaces = {}
    end
    for key, value in pairs(t) do
        -- Find namespace prefixes for DAV
        if not string.startswith(key, "_") then
            if value._attr and type(value._attr) == "table" then
                for attrKey, attrValue in pairs(value._attr) do
                    if string.startswith(attrKey, "xmlns") and attrValue == "DAV:" then
                        if attrKey ~= "xmlns" then
                            local namespacePrefix = string.sub(attrKey, #"xmlns:" + 1)
                            table.insert(knownNamespaces, namespacePrefix .. ":")
                            -- TODO: remove xmlns keys
                        end
                    end
                end
            end
        end
        -- Remove any discovered namespace prefixes for DAV from this element
        for _, ns in ipairs(knownNamespaces) do
            if string.startswith(key, ns) then
                local newKey = string.sub(key, #ns + 1)
                t[newKey] = t[key]
                t[key] = nil
            end
        end
        -- Recurse to this element's children
        if not string.startswith(key, "_") and type(value) == "table" then
            simplifyDavNamespace(value, knownNamespaces)
        end
    end
end

local function Rfc3339Time(secs)
    local year, mon, mday, hour, min, sec, gmtoffsec = unix.localtime(secs)
    return '%.4d-%.2d-%.2dT%.2d:%.2d:%.2d%+.2d:%.2d' % {
        year, mon, mday, hour, min, sec,
        gmtoffsec / (60 * 60), math.abs(gmtoffsec) % 60
    }
end

local function processPropTag(path, contents)
    local result = {}
    for tag, value in pairs(contents) do
        local stat = unix.stat(path)
        if tag == "resourcetype" then
            if unix.S_ISDIR(stat:mode()) then
                result["D:resourcetype"] = {["D:collection"] = {}}
            end
        end
        if tag == "creationdate" then
            local birthtime = stat:birthtim()
            result["D:creationdate"] = Rfc3339Time(birthtime)
        end
        if tag == "getcontentlength" then
            result["D:getcontentlength"] = tostring(stat:size())
        end
        if tag == "getlastmodified" then
            local lastmod = stat:mtim()
            result["D:getlastmodified"] = Rfc3339Time(lastmod)
        end
    end
    return result
end

local function processPropfindTag(path, contents)
    local result = {}
    for tag, value in pairs(contents) do
        if tag == "prop" then
            local props = processPropTag(path, value)
            result["D:prop"] = props
        end
    end
    return result
end

--- Handle a WebDAV PROPFIND request.
--- @param path (string) The request path.
--- @param body (string) The request body.
local function handlePropfind(path, body)
    local realpath = Root .. path
    local requestContentType = assert(GetHeader("Content-Type"))
    if (requestContentType ~= "application/xml") and (requestContentType ~= "text/xml") then
        ServeError(400, "Invalid Content-Type")
        return
    end
    local depth = GetHeader("Depth")
    if depth ~= "0" and depth ~= "1" then
        ServeError(400, "This server only supports depths of 0 or 1.")
        return
    end
    local handler = Handler:new()
    local parser = Xml2Lua.parser(handler)
    parser:parse(body)
    print(EncodeJson(handler.root))
    simplifyDavNamespace(handler.root)
    print(EncodeJson(handler.root))
    local responses = {}
    for tag, value in pairs(handler.root) do
        if tag == "propfind" then
            local propStats = processPropfindTag(realpath, value)
            table.insert(responses, {
                ["D:href"] = path,
                ["D:propstat"] = propStats
            })
            if depth == "1" then
                for name, kind, ino, off in assert(unix.opendir(realpath)) do
                    if not string.startswith(name, ".") then
                        local memberPath = realpath .. name
                        local memberPropStats = processPropfindTag(
                            memberPath,
                            value
                        )
                        table.insert(responses, {
                            ["D:href"] = path .. name,
                            ["D:propstat"] = memberPropStats
                        })
                    end
                end
            end
        end
    end
    local fullAnswer = {["D:multistatus"] = {
        _attr = { ["xmlns:D"] = "DAV:" },
        ["D:response"] = responses
    }}
    SetStatus(207)
    SetHeader("Content-Type", "application/xml")

    Write[[<?xml version="1.0" encoding="utf-8"?>]]
    local answerXml = Xml2Lua.toXml(fullAnswer)
    Log(kLogDebug, answerXml)
    Write(answerXml)
end

local function humanFileSize(bytes)
    local suffix = " B"
    local hvalue = bytes
    if hvalue >= 1024 then
        hvalue = hvalue / 1024
        suffix = "KB"
    end
    if hvalue >= 1024 then
        hvalue = hvalue / 1024
        suffix = "MB"
    end
    if hvalue >= 1024 then
        hvalue = hvalue / 1024
        suffix = "GB"
    end
    if hvalue >= 1024 then
        hvalue = hvalue / 1024
        suffix = "TB"
    end
    if hvalue >= 1024 then
        hvalue = hvalue / 1024
        suffix = "PB"
    end
    if hvalue >= 1024 then
        hvalue = hvalue / 1024
        suffix = "EB"
    end
    if hvalue >= 1024 then
        hvalue = hvalue / 1024
        suffix = "YB"
    end
    return string.format("%.0f %s", hvalue, suffix)
end

local function handleGet(path)
    local fullpath = Root .. path
    local stat = unix.stat(fullpath)
    if unix.S_ISDIR(stat:mode()) then
        Write(string.format([[<!doctype html>
            <meta charset="utf-8">
            <title>Index of %s</title>
            <style>
            html { color: #111; font-family: 'Comic Sans MS', 'Chalkboard SE', 'Comic Neue', sans-serif; }
            a { text-decoration: none; }
            pre a:hover { color: #00e; border-bottom: 1px solid #ccc; }
            h1 a { color: #111; }
            </style>
            <header><h1>Index of %s</h1><hr></header>
            <pre>]],
            path,
            path
        ))
        local entries = {}
        local nameWidth = 80
        local fileSizeWidth = 0
        for name, kind, _, _ in assert(unix.opendir(fullpath)) do
            Log(kLogDebug, "Examining " .. name)
            -- Exclude block devices, symlinks, etc.
            if not string.startswith(name, ".")
                and not IsHiddenPath(name)
                and (kind == unix.DT_REG or kind == unix.DT_DIR)
            then
                Log(kLogDebug, "File is OK to index")
                if kind == unix.DT_DIR then
                    name = name ..  "/"
                end
                Log(kLogDebug, "About to stat " .. fullpath .. name)
                local substat, errno = unix.stat(fullpath .. name)
                if substat then
                    local controlSafeName = VisualizeControlCodes(name)
                    nameWidth = math.max(nameWidth, GetMonospaceWidth(controlSafeName))
                    local sz = substat:size()
                    local szStr = humanFileSize(sz)
                    fileSizeWidth = math.max(fileSizeWidth, #szStr)
                    table.insert(entries, {
                        kind,
                        name,
                        EscapeHtml(controlSafeName),
                        szStr,
                        substat:birthtim()
                    })
                else
                    Log(kLogWarn, "Failed to read file while generating index page: " .. tostring(errno))
                end
            end
        end
        local function compareEntries(a, b)
            -- Sort first by kind, then by name.
            if a[1] ~= b[1] then
                -- Directories come before regular files.
                return a[1] < b[1]
            else
                return a[2] < b[2]
            end
        end
        table.sort(entries, compareEntries)
        -- Lua's string.format implementation doesn't support * modifiers :(
        local fmtstr = string.format('<a href="%%s">%%-%ds</a>  %%s  %%%ds\n', nameWidth, fileSizeWidth)
        for _, entry in ipairs(entries) do
            local urlSafePath = EscapeHtml(EscapePath(path .. entry[2]))
            local rfc3339Birthtm = Rfc3339Time(entry[5])
            Write(string.format(
                fmtstr,
                urlSafePath,
                entry[3],
                rfc3339Birthtm,
                entry[4]
            ))
        end
        Write[[</pre>]]
    else
        -- Not a directory; don't generate index page.
        Route()
    end
end

return {
    handlePropfind = handlePropfind,
    handleGet = handleGet,
    simplifyDavNamespace = simplifyDavNamespace
}
