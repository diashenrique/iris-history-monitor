/// Builds history series with coverage and cursor (user story 2, spec FR-003, FR-004, FR-009,
/// data-model HistorySeries, research.md R2, R4, R9).
///
/// Reads the System Monitor tables in %SYS. Every SYS.History row is keyed by ZDATE and ZTIME, which
/// are UTC (DateTime is local time), so timestamps are UTC without any time zone conversion. A key is
/// handled as one number: ZDATE * 86400 + ZTIME seconds.
///
/// Series reads the rows; Build turns them into the response and holds the paging, coverage and
/// partial rules. All results live in local variables: nothing is written to a global.
Class diashenrique.historymonitor.service.History
{

/// clean holds the values normalized by service.Validate.History.
ClassMethod Series(ByRef clean) As %DynamicObject
{
	Set metric = clean("metric"), grain = clean("granularity")
	Set fromKey = ..Key(clean("from")), toKey = ..Key(clean("to"))
	Set lo = fromKey
	If $Get(clean("cursor")) '= "" {
		Set after = ..Key(clean("cursor")) + 1
		If after > lo Set lo = after
	}
	Do ..Coverage(grain, fromKey, toKey, .first, .last)
	Do ..Rows(metric, grain, lo, toKey, $Get(clean("database")), clean("limit"), .rows)
	Quit ..Build(.clean, .rows, first, last, ..NowKey())
}

/// rows(n) = $ListBuild(key, series name, value), oldest first; it may hold the first row of one key
/// past the limit, which is how truncation is detected. first and last are the keys present in the
/// whole range ("" when none). nowKey is the current UTC key.
ClassMethod Build(ByRef clean, ByRef rows, first As %String, last As %String, nowKey As %Integer) As %DynamicObject
{
	Set grain = clean("granularity"), limit = clean("limit")
	Set fromKey = ..Key(clean("from")), toKey = ..Key(clean("to"))

	Set body = {}
	Do body.%Set("metric", clean("metric"), "string")
	Do body.%Set("granularity", grain, "string")
	Do body.%Set("from", ..Iso(fromKey), "string")
	Do body.%Set("to", ..Iso(toKey), "string")
	If first = "" {
		Do body.%Set("coverage", "", "null")
	} Else {
		Do body.%Set("coverage", {"first": (..Iso(first)), "last": (..Iso(last))})
	}
	// Partial when data is missing at either end by more than one step. The part of the range that
	// is still in the future cannot hold data, so the end is measured up to now.
	Set step = $Case(grain, "5min": 300, "hourly": 3600, : 86400)
	Set end = $Select(toKey > nowKey: nowKey, 1: toKey)
	Set partial = (first = "") || ((first - fromKey) > step) || ((end - last) > step)
	Do body.%Set("partial", partial, "boolean")

	// Paging counts timestamps, not points: one timestamp gives one point per series.
	Set count = 0, prev = "", truncated = 0, n = ""
	For {
		Set n = $Order(rows(n), 1, row)
		Quit:n=""
		Set key = $List(row, 1)
		If key '= prev {
			Set count = count + 1
			If count > limit {
				Set truncated = 1
				Quit
			}
			Set prev = key
		}
		// An empty value means the metric was not collected at that time; it is left out, not sent as 0.
		Set v = $ListGet(row, 3)
		If v '= "" Set points($List(row, 2), key) = +v
	}
	Do body.%Set("truncated", truncated, "boolean")
	If truncated Do body.%Set("next", ..Iso(prev), "string")

	Set series = [], name = ""
	For {
		Set name = $Order(points(name))
		Quit:name=""
		Set list = [], key = ""
		For {
			Set key = $Order(points(name, key), 1, v)
			Quit:key=""
			Set point = {"t": (..Iso(key))}
			Do point.%Set("v", v, "number")
			Do list.%Push(point)
		}
		Do series.%Push({"name": (name), "points": (list)})
	}
	Do body.%Set("series", series)
	Quit body
}

/// The SQL for one metric and granularity. Every fragment is a constant chosen by values that already
/// passed the allow-list in service.Validate; request values only ever reach the query as parameters.
/// Parameters: first date, last date, first key, last key, then the database key when filtered.
ClassMethod Query(metric As %String, grain As %String, filtered As %Boolean) As %String
{
	Set col = $Case(metric, "license": "Sys_LicUsedLocal", "csp-sessions": "Sys_CSPSession", : "DB_FileSize")
	If (grain = "5min") && (metric '= "database-size") {
		Quit "SELECT ZDATE AS D, ZTIME AS S, 'value' AS K, "_col_" AS V FROM SYS_History.SysData WHERE ZDATE BETWEEN ? AND ? AND (ZDATE * 86400 + ZTIME) BETWEEN ? AND ? ORDER BY ZDATE, ZTIME"
	}
	Set ref = $Case(grain, "5min": "SysData", "hourly": "Hourly", : "Daily")
	Set table = ref_$Select(metric = "database-size": "_DB", 1: "_Sys")
	Set sql = "SELECT "_ref_"->ZDATE AS D, "_ref_"->ZTIME AS S, element_key AS K, "_col_" AS V FROM SYS_History."_table
	Set sql = sql_" WHERE "_ref_"->ZDATE BETWEEN ? AND ? AND ("_ref_"->ZDATE * 86400 + "_ref_"->ZTIME) BETWEEN ? AND ?"
	If metric '= "database-size" {
		// The statistics the pages show; StDev is left out.
		Set sql = sql_" AND element_key IN ('Avg', 'Max')"
	} ElseIf filtered {
		Set sql = sql_" AND element_key = ?"
	} ElseIf grain '= "5min" {
		// Hourly and daily database rows are <name>_Avg, _Max and _StDev; the size is the Max.
		Set sql = sql_" AND element_key LIKE '%\_Max' ESCAPE '\'"
	}
	Quit sql_" ORDER BY "_ref_"->ZDATE, "_ref_"->ZTIME, element_key"
}

/// Reads rows oldest first and stops at the first row of the timestamp after limit.
ClassMethod Rows(metric As %String, grain As %String, lo As %Integer, hi As %Integer, database As %String, limit As %Integer, Output rows)
{
	Kill rows
	Quit:lo>hi
	New $Namespace
	Set $Namespace = "%SYS"
	Set filtered = (metric = "database-size") && (database '= "")
	Set stmt = ##class(%SQL.Statement).%New()
	$$$ThrowOnError(stmt.%Prepare(..Query(metric, grain, filtered)))
	If filtered {
		Set dbKey = database_$Select(grain = "5min": "", 1: "_Max")
		Set rs = stmt.%Execute(lo \ 86400, hi \ 86400, lo, hi, dbKey)
	} Else {
		Set rs = stmt.%Execute(lo \ 86400, hi \ 86400, lo, hi)
	}
	If rs.%SQLCODE < 0 Throw ##class(%Exception.SQL).CreateFromSQLCODE(rs.%SQLCODE, rs.%Message)
	Set n = 0, count = 0, prev = ""
	While rs.%Next() {
		Set key = (rs.D * 86400) + rs.S
		If key '= prev {
			Set count = count + 1, prev = key
		}
		Set name = rs.K
		If (metric = "database-size") && (grain '= "5min") Set name = $Extract(name, 1, *-4)
		Set rows($Increment(n)) = $ListBuild(key, name, rs.V)
		Quit:count>limit
	}
}

/// First and last key present in the range, from the summary table of the granularity.
ClassMethod Coverage(grain As %String, fromKey As %Integer, toKey As %Integer, Output first, Output last)
{
	Set (first, last) = ""
	New $Namespace
	Set $Namespace = "%SYS"
	Set table = $Case(grain, "5min": "SysData", "hourly": "Hourly", : "Daily")
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT MIN(ZDATE * 86400 + ZTIME) AS A, MAX(ZDATE * 86400 + ZTIME) AS B FROM SYS_History."_table_" WHERE ZDATE BETWEEN ? AND ? AND (ZDATE * 86400 + ZTIME) BETWEEN ? AND ?", fromKey \ 86400, toKey \ 86400, fromKey, toKey)
	If rs.%SQLCODE < 0 Throw ##class(%Exception.SQL).CreateFromSQLCODE(rs.%SQLCODE, rs.%Message)
	If rs.%Next() {
		Set first = rs.A, last = rs.B
	}
}

/// "YYYY-MM-DD hh:mm:ss" (UTC, as normalized by Validate) to seconds since the $H epoch.
ClassMethod Key(utc As %String) As %Integer
{
	Set h = $ZDateTimeH(utc, 3)
	Quit (+h * 86400) + $Piece(h, ",", 2)
}

/// Seconds since the $H epoch to "YYYY-MM-DDThh:mm:ssZ". The key is already UTC; $ZDateTime time
/// format 7 would convert it from local time again, so the T and Z are added here.
ClassMethod Iso(key As %Integer) As %String
{
	Quit $Translate($ZDateTime((key \ 86400)_","_(key # 86400), 3, 1), " ", "T")_"Z"
}

ClassMethod NowKey() As %Integer
{
	Set h = $ZTimeStamp
	Quit (+h * 86400) + ($Piece(h, ",", 2) \ 1)
}

}
