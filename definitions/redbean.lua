--- @meta

--- @alias LogLevel integer

--- @type (LogLevel) Integer for debug logging level.
--- @see Log
kLogDebug = 5
--- @type (LogLevel) Integer for verbose logging level, which is less than kLogDebug. @see Log
kLogVerbose = 4
--- @type (LogLevel) Integer for info logging level, which is less than kLogVerbose.
--- @see Log
kLogInfo = 3
--- @type (LogLevel) Integer for warn logging level, which is less than kLogVerbose.
--- @see Log
kLogWarn = 2
--- @type (LogLevel) Integer for error logging level, which is less than kLogWarn.
--- @see Log
kLogError = 1
--- @type (LogLevel) Integer for fatal logging level, which is less than kLogError.
--- Logging anything at this level will result in a backtrace and process exit.
--- @see Log
kLogFatal = 0

--- Emits message string to log, if level is less than or equal to GetLogLevel.
--- If redbean is running in interactive mode, then this will log to the console.
--- If redbean is running as a daemon or the -L LOGFILE flag is passed, then
--- this will log to the file. Reasonable values for level are:
--- kLogDebug > kLogVerbose > kLogInfo > kLogWarn > kLogError > kLogFatal.
--- The logger emits timestamps in the local timezone with microsecond precision.
--- If log entries are emitted more frequently than once per second, then the
--- log entry will display a delta timestamp, showing how much time has elapsed
--- since the previous log entry. This behavior is useful for quickly measuring
--- how long various portions of your code take to execute.
--- @param level (integer) The severity of the log message.
--- @param message (string) The message to log.
function Log(level, message)
end

--- @alias EncodeJsonOptions {useoutput: boolean, sorted: boolean, pretty: boolean, indent: string, maxdepth: integer}

--- Turns Lua data structure into JSON string.
--- Since Lua tables are both hashmaps and arrays, we use a simple fast
--- algorithm for telling the two apart. Tables with non-zero length (as
--- reported by #) are encoded as arrays, and any non-array elements are ignored.
--- The following options may be used:
--- - useoutput: (boolean=false) encodes the result directly to the output buffer and returns nil value. This option is ignored if used outside of request handling code.
--- - sorted: (boolean=true) Lua uses hash tables so the order of object keys is lost in a Lua table. So, by default, we use strcmp to impose a deterministic output order. If you don't care about ordering then setting sorted=false should yield a performance boost in serialization.
--- - pretty: (boolean=false) Setting this option to true will cause tables with more than one entry to be formatted across multiple lines for readability.
--- - indent: (string=" ") This option controls the indentation of pretty formatting. This field is ignored if pretty isn't true.
--- - maxdepth: (integer=64) This option controls the maximum amount of recursion the serializer is allowed to perform. The max is 32767. You might not be able to set it that high if there isn't enough C stack memory. Your serializer checks for this and will return an error rather than crashing.
--- @param value (table) The table to serialize into JSON.
--- @param options (EncodeJsonOptions | nil) Options to alter how the data is serialized, in a table.
--- @return (string | nil) A JSON representation of the input table, or nil if there was a serialization error.
--- @return (nil | string) If there was an error, a string error message describing the problem.
function EncodeJson(value, options)
end

--- Turns JSON string into a Lua data structure.
---
--- This is a generally permissive parser, in the sense that like v8, it permits
--- scalars as top-level values. Therefore we must note that this API can be
--- thought of as special, in the sense
---
---     val = assert(DecodeJson(str))
---
--- will usually do the right thing, except in cases where false or null are the
--- top-level value. In those cases, it's needed to check the second value too
--- in order to discern from error.
---
--- This parser supports 64-bit signed integers. If an overflow happens, then
--- the integer is silently coerced to double, as consistent with v8. If a
--- double overflows into Infinity, we coerce it to null since that's what v8
--- does, and the same goes for underflows which, like v8, are coerced to 0.0.
---
--- When objects are parsed, your Lua object can't preserve the original
--- ordering of fields. As such, they'll be sorted by `EncodeJson()` and may not
--- round-trip with original intent
---
--- This parser has perfect conformance with JSONTestSuite.
---
--- This parser validates utf-8 and utf-16.
--- @param input (string) A string containing JSON to decode.
--- @return (table | string | integer | number | boolean | nil) The decoded JSON input (which may be `nil` if the input was `null`), or `nil` if there was an error.
--- @return (nil | string) `nil`, unless there was an error decoding, in which case it will be a string error message describing the problem.
function DecodeJson(input)
end

--- Appends data to HTTP response payload buffer. This is buffered independently
--- of headers.
--- @param data (string) Data to append to the HTTP response payload buffer.
function Write(data)
end

--- Starts an HTTP response, specifying the parameters on its first line. reason
--- is optional since redbean can fill in the appropriate text for well-known
--- magic numbers, e.g. 200, 404, etc. This method will reset the response and
--- is therefore mutually exclusive with ServeAsset and other Serve* functions.
--- If a status setting function isn't called, then the default behavior is to
--- send 200 OK.
--- @param code (integer) The HTTP status code to use for the response.
--- @param reason (string | nil) The HTTP status text for the response. If `nil`,
---        and `code` is one of the well-known HTTP status codes, the conventional
---        string for that code will be used.
function SetStatus(code, reason)
end

--- Appends HTTP header to response header buffer. Leading and trailing
--- whitespace is trimmed from both arguments automatically. Overlong
--- characters are canonicalized. C0 and C1 control codes are forbidden, with
--- the exception of tab. This function automatically calls `SetStatus(200, "OK")`
--- if a status has not yet been set. As `SetStatus` and `Serve*` functions
--- reset the response, `SetHeader` needs to be called after `SetStatus` and
--- `Serve*` functions are called. The header buffer is independent of the
--- payload buffer. Neither is written to the wire until the Lua Server Page
--- has finished executing. This function disallows the setting of certain
--- headers such as and Content-Range which are abstracted by the transport
--- layer. In such cases, consider calling `ServeAsset`.
--- @see ServeAsset
--- @see SetStatus
--- @see SetHeader
--- @param name (string) Header name. Case-insensitive and restricted to non-space ASCII.
--- @param value (string) Header value. UTF-8 string that must be encodable as ISO-8859-1.
function SetHeader(name, value)
end

--- Returns first value associated with name. name is handled in a
--- case-sensitive manner. This function checks Request-URL parameters first.
--- Then it checks application/x-www-form-urlencoded from the message body, if
--- it exists, which is common for HTML forms sending POST requests. If a
--- parameter is supplied matching name that has no value, e.g. `foo` in
--- `?foo&bar=value`, then the returned value will be `nil`, whereas for
--- `?foo=&bar=value` it would be `""`. To differentiate between no-equal and
--- absent, use the @see HasParam function. The returned value is decoded from
--- ISO-8859-1 (only in the case of Request-URL) and we assume that
--- percent-encoded characters were supplied by the client as UTF-8 sequences,
--- which are returned exactly as the client supplied them, and may therefore
--- may contain overlong sequences, control codes, NUL characters, and even
--- numbers which have been banned by the IETF. It is the responsibility of
--- the caller to impose further restrictions on validity, if they're desired.
--- @param name (string) Parameter name for which to get the associated value.
--- @return (string | nil) The value of the parameter `name`, or nil/"" as described above.
function GetParam(name)
end

--- Escapes HTML entities: The set of entities is `&><"'` which become
--- `&amp;&gt;&lt;&quot;&#39;`. This function is charset agnostic and will not
--- canonicalize overlong encodings. It is assumed that a UTF-8 string will be
--- supplied.
--- @param str (string) The string in which to escape HTML entities.
--- @return (string) A new string, where all prohibited characters in `str` have
---         been replaced as described above.
function EscapeHtml(str)
end

--- Escapes URL parameter name or value. The allowed characters are
--- `-.*_0-9A-Za-z` and everything else gets `%XX` encoded. This function is
--- charset agnostic and will not canonicalize overlong encodings. It is assumed
--- that a UTF-8 string will be supplied.
--- @param str (string) The URL parameter name/value to encode
--- @return (string) A clone of `str`, but with invalid characters replaced with their percent encoded equivalent.
function EscapeParam(str)
end

--- Escapes URL path. This is the same as EscapeSegment except slash is allowed.
--- The allowed characters are `-.~_@:!$&'()*+,;=0-9A-Za-z/` and everything else
--- gets `%XX` encoded. Please note that `'&` can still break HTML, so the output
--- may need `EscapeHtml` too. Also note that `'()` can still break CSS URLs.
--- This function is charset agnostic and will not canonicalize overlong
--- encodings. It is assumed that a UTF-8 string will be supplied.
--- @param str (string) A string that needs to be included in a URL path.
--- @return (string) A copy of `str` that is safe to include in a URL path.
function EscapePath(str)
end

--- @alias URL {scheme: (string|nil), user: (string|nil), pass: (string|nil), host: (string|nil), port: (string|nil), path: (string|nil), params: string[][], fragment: (string|nil)}

--- Parses URL.
---
--- An object containing the following fields is returned:
--- - scheme is a string, e.g. "http"
--- - user is the username string, or nil if absent
--- - pass is the password string, or nil if absent
--- - host is the hostname string, or nil if url was a path
--- - port is the port string, or nil if absent
--- - path is the path string, or nil if absent
--- - params is the URL paramaters, e.g. `/?a=b&c` would be represented as the data structure `{{"a", "b"}, {"c"}, ...}`
--- - fragment is the stuff after the `#` character
---
--- This parser is charset agnostic. Percent encoded bytes are decoded for all
--- fields. Returned values might contain things like NUL characters, spaces,
--- control codes, and non-canonical encodings. Absent can be discerned from
--- empty by checking if the pointer is set.
---
--- There's no failure condition for this routine. This is a permissive parser.
--- This doesn't normalize path segments like . or .. so use IsAcceptablePath()
--- to check for those. No restrictions are imposed beyond that which is
--- strictly necessary for parsing. All the data that is provided will be
--- consumed to the one of the fields. Strict conformance is enforced on some
--- fields more than others, like scheme, since it's the most
--- non-deterministically defined field of them all.
---
--- Please note this is a URL parser, not a URI parser. Which means we support
--- everything the URI spec says we should do except for the things we won't do,
--- like tokenizing path segments into an array and then nesting another array
--- beneath each of those for storing semicolon parameters. So this parser won't
--- make SIP easy. What it can do is parse HTTP URLs and most URIs like
--- data:opaque, better in fact than most things which claim to be URI parsers.
--- @param str (string) The URL string to parse.
--- @return (URL) A parsed table of URL data, as described above.
function ParseUrl(str)
end

--- This function is the inverse of ParseUrl. The output will always be
--- correctly formatted. The exception is if illegal characters are supplied in
--- the scheme field, since there's no way of escaping those. Opaque parts are
--- escaped as though they were paths, since many URI parsers won't understand
--- things like an unescaped question mark in path.
--- @see ParseUrl
--- @param url (URL) The URL to encode as a string.
--- @return (string) A string equivalent to the provided URL object.
function EncodeUrl(url)
end

--- @alias FetchOptions { body: string?, method: string?, headers: { [string]: (string | number)}?, followredirect: boolean?, maxredirects: integer?}

--- Sends an HTTP/HTTPS request to the specified URL. If only the URL is
--- provided, then a GET request is sent. If both URL and body parameters are
--- specified, then a POST request is sent. If any other method needs to be
--- specified (for example, PUT or DELETE), then passing a table as the second
--- value allows setting method and body values as well other options:
--- - method (default: "GET"): sets the method to be used for the request. The specified method is converted to uppercase.
--- - body (default: ""): sets the body value to be sent.
--- - headers sets headers for the request using the key/value pairs from this table. Only string keys are used and all the values are converted to strings.
--- - followredirect (default: true): forces temporary and permanent redirects to be followed. This behavior can be disabled by passing false.
--- - maxredirects (default: 5): sets the number of allowed redirects to minimize looping due to misconfigured servers. When the number is exceeded, the result of the last redirect is returned.
--- When the redirect is being followed, the same method and body values are
--- being sent in all cases except when 303 status is returned. In that case
--- the method is set to GET and the body is removed before the redirect is
--- followed. Note that if these (method/body) values are provided as table
--- fields, they will be modified in place.
--- @param url (string) The to which to send the request.
--- @param bodyOrOpts (string | FetchOptions) If this is a string, the request body. If it is a table, options that control how the request is made (including a body), described above.
--- @return (integer | nil) HTTP status code for the response, or nil if there was an error.
--- @return ({[string]: string} | string) A table of string=string header names and values, or an error message describing the problem.
--- @return (string | nil) The response body, or `nil` if there was an error.
function Fetch(url, bodyOrOpts)
end

--- Converts UNIX timestamp to an RFC1123 string that looks like this:
---     Mon, 29 Mar 2021 15:37:13 GMT
--- @param seconds (integer) UNIX timestamp (seconds since midnight, Jan 1 1970 GMT).
--- @return (string) An RFC1123 string representing the time in GMT provided as input.
function FormatHttpDateTime(seconds)
end

--- Returns true if parameter with name was supplied in either the Request-URL
--- or an application/x-www-form-urlencoded message body.
--- @param name (string) The name of the parameter to check for.
--- @return (boolean) True if the parameter was provided (even with no value), false otherwise.
function HasParam(name)
end

--- Returns the Request-URL path. This is guaranteed to begin with `/`. It is
--- further guaranteed that no `//` or `/.` exists in the path. The returned
--- value is returned as a UTF-8 string which was decoded from ISO-8859-1. We
--- assume that percent-encoded characters were supplied by the client as
--- UTF-8 sequences, which are returned exactly as the client supplied them,
--- and may therefore may contain overlong sequences, control codes, NUL
--- characters, and even numbers which have been banned by the IETF. redbean
--- takes those things into consideration when performing path safety checks.
--- It is the responsibility of the caller to impose further restrictions on
--- validity, if they're desired.
--- @return (string) The request URL.
function GetPath()
end

--- Returns string with the specified number of random bytes (1..256).
--- If no length is specified, then a string of length 16 is returned.
--- @param length (nil|integer) Number of random bytes to include in the returned string (1..256).
--- @return (string) A string of random bytes of the specified length, or 16 if no length specified.
function GetRandomBytes(length)
end

--- Instructs redbean to follow the normal HTTP serving path. This function is
--- useful when writing an `OnHttpRequest` handler, since that overrides the
--- serving path entirely. So if the handler decides it doesn't want to do
--- anything, it can simply call this function, to hand over control back to the
--- redbean core. By default, the host and path arguments are supplied from the
--- resolved GetUrl value. This handler always resolves, since it will generate
--- a 404 Not Found response if redbean couldn't find an appropriate endpoint.
--- @see GetUrl
--- @param host (string|nil) The virtual host for a particular request. If not provided, resolved from `GetUrl`.
--- @param path (string|nil) The path for a particular request. If not provided, resolved from `GetUrl`.
function Route(host, path)
end
