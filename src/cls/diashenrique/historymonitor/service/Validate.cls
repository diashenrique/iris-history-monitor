/// Allow-list and strict-format validation of request inputs (spec FR-006).
/// Each validator returns "" when the value is valid, otherwise a short message.
/// Normalized values leave through an Output argument and stay "" on failure.
/// Nothing here executes or concatenates request data; values are only compared or pattern-matched.
Class diashenrique.historymonitor.service.Validate
{

Parameter MAXLIMIT = 5000;

Parameter DEFAULTLIMIT = 1000;

/// Accepts YYYY-MM-DD (midnight UTC) and YYYY-MM-DDThh:mm[:ss][Z]. utc comes back as "YYYY-MM-DD hh:mm:ss".
ClassMethod Date(value As %String, Output utc As %String) As %String
{
	Set utc = ""
	Set v = $Get(value)
	Set msg = "must be an ISO 8601 date (YYYY-MM-DD) or UTC date-time (YYYY-MM-DDThh:mm:ssZ)"
	If ($Length(v) > 10) && ($Extract(v, *) = "Z") Set v = $Extract(v, 1, *-1)
	If v ? 4N1"-"2N1"-"2N {
		Set date = v, time = "00:00:00"
	} ElseIf v ? 4N1"-"2N1"-"2N1"T"2N1":"2N {
		Set date = $Piece(v, "T", 1), time = $Piece(v, "T", 2)_":00"
	} ElseIf v ? 4N1"-"2N1"-"2N1"T"2N1":"2N1":"2N {
		Set date = $Piece(v, "T", 1), time = $Piece(v, "T", 2)
	} Else {
		Quit msg
	}
	Try {
		Set h = $ZDateTimeH(date_" "_time, 3, 1, , , , , , , "invalid")
	} Catch {
		Set h = "invalid"
	}
	If h '[ "," Quit msg
	Set utc = $ZDateTime(h, 3, 1)
	Quit ""
}

/// from and to are values already normalized by Date.
ClassMethod Range(from As %String, to As %String) As %String
{
	If ($Get(from) = "") || ($Get(to) = "") Quit "from and to are required"
	If from ] to Quit "from must not be after to"
	Quit ""
}

ClassMethod Enum(value As %String, allowed As %String) As %String
{
	Set v = $Get(value)
	If v = "" Quit "is required; allowed values: "_allowed
	If $ListFind($ListFromString(allowed), v) Quit ""
	Quit "must be one of: "_allowed
}

ClassMethod Metric(value As %String) As %String
{
	Quit ..Enum($Get(value), "license,csp-sessions,database-size")
}

ClassMethod Granularity(value As %String) As %String
{
	Quit ..Enum($Get(value), "5min,hourly,daily")
}

/// Absent means the default; otherwise 1 to 5000 digits only (no sign, spaces, decimals or exponent).
ClassMethod Limit(value As %String, Output n As %Integer) As %String
{
	Set n = ""
	Set v = $Get(value)
	If v = "" {
		Set n = ..#DEFAULTLIMIT
		Quit ""
	}
	Set msg = "must be an integer from 1 to "_..#MAXLIMIT
	If v '? 1.4N Quit msg
	If (+v < 1) || (+v > ..#MAXLIMIT) Quit msg
	Set n = +v
	Quit ""
}

/// 1 to 64 ASCII letters, digits, underscore, dot, percent or hyphen (same pattern as the contract).
ClassMethod Database(value As %String) As %String
{
	Set v = $Get(value)
	Set msg = "must be 1 to 64 characters of letters, digits, '_', '.', '%' or '-'"
	// $MATCH needs the whole string to match, and the explicit ASCII classes keep Unicode letters out.
	If '$Match(v, "[A-Za-z0-9_.%-]{1,64}") Quit msg
	Quit ""
}

/// Validates a whole GET /history/{metric} request and returns a %DynamicArray of
/// {parameter, message}; empty means valid. q is subscripted by query parameter name.
/// clean receives the normalized values, only for parameters that passed.
ClassMethod History(metric As %String, ByRef q, Output clean) As %DynamicArray
{
	Kill clean
	Set errs = []
	Set err = ..Metric(metric)
	If err '= "" { Do ..Add(errs, "metric", err) } Else { Set clean("metric") = metric }
	Set err = ..Granularity($Get(q("granularity")))
	If err '= "" { Do ..Add(errs, "granularity", err) } Else { Set clean("granularity") = q("granularity") }
	Set fromErr = ..Date($Get(q("from")), .from)
	If fromErr '= "" Do ..Add(errs, "from", fromErr)
	Set toErr = ..Date($Get(q("to")), .to)
	If toErr '= "" Do ..Add(errs, "to", toErr)
	If (fromErr = "") && (toErr = "") {
		Set err = ..Range(from, to)
		If err '= "" { Do ..Add(errs, "from", err) } Else { Set clean("from") = from, clean("to") = to }
	}
	Set err = ..Limit($Get(q("limit")), .limit)
	If err '= "" { Do ..Add(errs, "limit", err) } Else { Set clean("limit") = limit }
	// cursor is the "next" value of a previous page: a UTC timestamp, checked like from and to.
	If $Get(q("cursor")) '= "" {
		Set err = ..Date(q("cursor"), .cursor)
		If err '= "" { Do ..Add(errs, "cursor", err) } Else { Set clean("cursor") = cursor }
	}
	If $Get(q("database")) '= "" {
		If metric '= "database-size" {
			Do ..Add(errs, "database", "is only valid for the database-size metric")
		} Else {
			Set err = ..Database(q("database"))
			If err '= "" { Do ..Add(errs, "database", err) } Else { Set clean("database") = q("database") }
		}
	}
	Quit errs
}

/// Optional free text: 1 to max characters, none of them a control character. Compared in
/// ObjectScript only, never placed in SQL.
ClassMethod Text(value As %String, max As %Integer) As %String
{
	Set v = $Get(value)
	Set msg = "must be 1 to "_max_" characters without control characters"
	If ($Length(v) < 1) || ($Length(v) > max) Quit msg
	If $Length($ZStrip(v, "*C")) '= $Length(v) Quit msg
	Quit ""
}

/// Absent means default; otherwise digits only, from 1 to max.
ClassMethod Positive(value As %String, max As %Integer, default As %Integer, Output n As %Integer) As %String
{
	Set n = ""
	Set v = $Get(value)
	If v = "" {
		Set n = default
		Quit ""
	}
	Set msg = "must be an integer from 1 to "_max
	If v '? 1.9N Quit msg
	If (+v < 1) || (+v > max) Quit msg
	Set n = +v
	Quit ""
}

/// Validates a whole GET /processes request and returns a %DynamicArray of {parameter, message};
/// empty means valid. clean receives namespace, user, state, q, sortField, sortDesc, page, pageSize.
ClassMethod Processes(ByRef q, Output clean) As %DynamicArray
{
	Kill clean
	Set errs = []
	For p = "namespace", "user", "state" {
		If $Get(q(p)) '= "" {
			Set err = ..Text(q(p), 128)
			If err '= "" { Do ..Add(errs, p, err) } Else { Set clean(p) = q(p) }
		}
	}
	If $Get(q("q")) '= "" {
		Set err = ..Text(q("q"), 100)
		If err '= "" { Do ..Add(errs, "q", err) } Else { Set clean("q") = q("q") }
	}
	Set clean("sortField") = "job", clean("sortDesc") = 0
	If $Get(q("sort")) '= "" {
		Set desc = ($Extract(q("sort")) = "-")
		Set field = $Select(desc: $Extract(q("sort"), 2, *), 1: q("sort"))
		Set fields = ##class(diashenrique.historymonitor.service.Processes).Fields()
		If (field = "") || '$ListFind(fields, field) {
			Do ..Add(errs, "sort", "must be a returned field, optionally prefixed with '-': "_$ListToString(fields, ", "))
		} Else {
			Set clean("sortField") = field, clean("sortDesc") = desc
		}
	}
	Set err = ..Positive($Get(q("page")), 999999, 1, .page)
	If err '= "" { Do ..Add(errs, "page", err) } Else { Set clean("page") = page }
	Set err = ..Positive($Get(q("pageSize")), 500, 100, .size)
	If err '= "" { Do ..Add(errs, "pageSize", err) } Else { Set clean("pageSize") = size }
	Quit errs
}

ClassMethod Add(errs As %DynamicArray, parameter As %String, message As %String) [ Private ]
{
	Set e = {}
	Do e.%Set("parameter", parameter, "string")
	Do e.%Set("message", message, "string")
	Do errs.%Push(e)
}

}
