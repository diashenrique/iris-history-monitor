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

ClassMethod Add(errs As %DynamicArray, parameter As %String, message As %String) [ Private ]
{
	Set e = {}
	Do e.%Set("parameter", parameter, "string")
	Do e.%Set("message", message, "string")
	Do errs.%Push(e)
}

}
