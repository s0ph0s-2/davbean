local luaunit = require "luaunit"
local dav = require "dav"

TestDav = {}

    function TestDav:testSimplifyDavNamespaceNoChanges()
        local input = { rss = { _attr = { foo = "bar", baz = "quux" }}}
        local expected = { rss = { _attr = { foo = "bar", baz = "quux" }}}
        dav.simplifyDavNamespace(input)
        luaunit.assertEquals(input, expected)
    end

    function TestDav:testSimplifyDavNamespaceOneElement()
        local input = { ["D:response"] = { _attr = { ["xmlns:D"] = "DAV:" }}}
        local expected = { ["response"] = { _attr = { ["xmlns:D"] = "DAV:" }}}
        dav.simplifyDavNamespace(input)
        luaunit.assertEquals(input, expected)
    end

    function TestDav:testSimplifyDavNamespaceNestedElementsSameNs()
        local input = { ["D:response"] = { _attr = { ["xmlns:D"] = "DAV:" }, ["D:status"] = "foo"}}
        local expected = { ["response"] = { _attr = { ["xmlns:D"] = "DAV:" }, status = "foo"}}
        dav.simplifyDavNamespace(input)
        luaunit.assertEquals(input, expected)
    end

    function TestDav:testSimplifyDavNamespaceNestedElementsDifferentNs()
        local input = {
            ["D:response"] = {
                _attr = {
                    ["xmlns:D"] = "DAV:"
                },
                ["webdav:status"] = {
                    _attr = { ["xmlns:webdav"] = "DAV:" },
                    [1] = "400"
                }
            }
        }
        local expected = {
            ["response"] = {
                _attr = {
                    ["xmlns:D"] = "DAV:"
                },
                ["status"] = {
                    _attr = { ["xmlns:webdav"] = "DAV:" },
                    [1] = "400"
                }
            }
        }
        dav.simplifyDavNamespace(input)
        luaunit.assertEquals(input, expected)
    end

os.exit( luaunit.LuaUnit.run() )
