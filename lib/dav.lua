local function processPropTag(path, contents)
    local result = {}
    for tag, value in pairs(contents) do
        if tag == "resourcetype" then
            local stat = unix.stat(path)
            if unix.S_ISDIR(stat:mode()) then
                result["D:resourcetype"] = {["D:collection"] = {}}
            end
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
        SetStatus(400)
        return
    end
    local depth = GetHeader("Depth")
    if depth ~= "0" and depth ~= "1" then
        SetStatus(400)
        Write("This server only supports depths of 0 or 1.")
        return
    end
    local handler = Handler:new()
    local parser = Xml2Lua.parser(handler)
    parser:parse(body)
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
                    if name ~= '.' and name ~= '..' then
                        local memberPath = realpath .. "/" .. name
                        local memberPropStats = processPropfindTag(
                            memberPath,
                            value
                        )
                        table.insert(responses, {
                            ["D:href"] = memberPath,
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
    SetHeader("DAV", "1")

    Write[[<?xml version="1.0" encoding="utf-8"?>]]
    local answerXml = Xml2Lua.toXml(fullAnswer)
    Log(kLogDebug, answerXml)
    Write(answerXml)
    --[[
    <D:multistatus xmlns:D="DAV:">
        <D:response>
            <D:href>http://localhost:8080/</D:href>
            <D:propstat>
                <D:prop>
                    <D:resourcetype>
                        <D:collection/>
                    </D:resourcetype>
                </D:prop>
            </D:propstat>
        </D:response>
    </D:multistatus>]]
end

return {handlePropfind = handlePropfind}
