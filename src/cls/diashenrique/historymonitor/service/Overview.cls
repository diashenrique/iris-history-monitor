/// Builds the overview snapshot (user story 1, spec FR-002, data-model OverviewSnapshot).
/// Every value comes from SYS.Stats.Dashboard.Sample(), the source both current dashboards show
/// (the SAM sensors of util.customSensors publish the same properties; see research.md R8).
///
/// Snapshot reads the live sample; Build turns raw values into the response and holds every rule, so
/// the unavailable and never-backed-up cases can be tested without changing the instance.
/// Nothing is written to a global.
Class diashenrique.historymonitor.service.Overview
{

/// Reason used when the sample cannot be read at all.
Parameter SAMPLEFAILED = "the dashboard sample could not be read";

/// License use at or above this percent is a warning.
Parameter LICENSEWARNING = 80;

/// License use at or above this percent is critical.
Parameter LICENSECRITICAL = 95;

/// One entry per metric, in response order: $ListBuild(name, dashboard property, unit, kind).
/// kind decides how the value is typed and how the status is set (see Metric).
ClassMethod Definitions() As %List
{
	Set d = ""
	Set d = d_$ListBuild($ListBuild("systemUpTime", "SystemUpTime", "text", "text"))
	Set d = d_$ListBuild($ListBuild("lastBackup", "LastBackup", "text", "backup"))
	Set d = d_$ListBuild($ListBuild("lockTable", "LockTable", "text", "state"))
	Set d = d_$ListBuild($ListBuild("journalSpace", "JournalSpace", "text", "state"))
	Set d = d_$ListBuild($ListBuild("journalStatus", "JournalStatus", "text", "state"))
	Set d = d_$ListBuild($ListBuild("ecpAppServer", "ECPAppServer", "text", "state"))
	Set d = d_$ListBuild($ListBuild("ecpDataServer", "ECPDataServer", "text", "state"))
	Set d = d_$ListBuild($ListBuild("writeDaemon", "WriteDaemon", "text", "state"))
	Set d = d_$ListBuild($ListBuild("licenseCurrent", "LicenseCurrent", "count", "number"))
	Set d = d_$ListBuild($ListBuild("licenseCurrentPct", "LicenseCurrentPct", "percent", "license"))
	Set d = d_$ListBuild($ListBuild("licenseHigh", "LicenseHigh", "count", "number"))
	Set d = d_$ListBuild($ListBuild("licenseHighPct", "LicenseHighPct", "percent", "license"))
	Set d = d_$ListBuild($ListBuild("licenseLimit", "LicenseLimit", "count", "number"))
	Set d = d_$ListBuild($ListBuild("applicationErrors", "ApplicationErrors", "count", "number"))
	Set d = d_$ListBuild($ListBuild("cspSessions", "CSPSessions", "count", "number"))
	Set d = d_$ListBuild($ListBuild("cacheEfficiency", "CacheEfficiency", "ratio", "number"))
	Set d = d_$ListBuild($ListBuild("processes", "Processes", "count", "number"))
	Set d = d_$ListBuild($ListBuild("seriousAlerts", "SeriousAlerts", "count", "alerts"))
	Quit d
}

/// The snapshot of the running instance. A sample that cannot be read gives every metric as unavailable.
ClassMethod Snapshot() As %DynamicObject
{
	Set failure = ""
	Try {
		Do ..Sample(.values)
	} Catch {
		Kill values
		Set failure = ..#SAMPLEFAILED
	}
	Quit ..Build(.values, failure)
}

/// Copies the dashboard properties into values(property). A property this IRIS version does not have
/// is left out, so its metric is reported as unavailable instead of failing the whole snapshot.
ClassMethod Sample(Output values)
{
	Kill values
	New $Namespace
	Set $Namespace = "%SYS"
	Set dashboard = ##class(SYS.Stats.Dashboard).Sample()
	Set defs = ..Definitions()
	For i = 1:1:$ListLength(defs) {
		Set prop = $List($List(defs, i), 2)
		Try {
			Set values(prop) = $Property(dashboard, prop)
		} Catch {
		}
	}
}

/// values(property) holds the raw dashboard values. failure, when not empty, marks every metric
/// unavailable with that reason.
ClassMethod Build(ByRef values, failure As %String = "") As %DynamicObject
{
	Set metrics = []
	Set defs = ..Definitions()
	For i = 1:1:$ListLength(defs) {
		Set def = $List(defs, i)
		Set prop = $List(def, 2)
		Do metrics.%Push(..Metric($List(def, 1), $List(def, 3), $List(def, 4), $Data(values(prop)), $Get(values(prop)), failure))
	}
	Quit {"generatedAt": (..UtcNow()), "metrics": (metrics)}
}

/// One metric. present is $Data of the raw value.
ClassMethod Metric(name As %String, unit As %String, kind As %String, present As %Boolean, raw As %String, failure As %String = "") As %DynamicObject
{
	Set m = {"name": (name)}
	If failure '= "" Quit ..Unavailable(m, unit, failure)
	If 'present Quit ..Unavailable(m, unit, "not reported by the dashboard sample")

	If kind = "backup" {
		// A backup that never ran is reported empty by the dashboard; that is a warning, not neutral text.
		If raw = "" {
			Do m.%Set("value", "", "null")
			Set status = "warning"
		} Else {
			Do m.%Set("value", raw, "string")
			Set status = "ok"
		}
	} ElseIf raw = "" {
		Quit ..Unavailable(m, unit, "no value reported")
	} ElseIf (kind = "text") || (kind = "state") {
		Do m.%Set("value", raw, "string")
		Set status = $Select(kind = "state": ..StateStatus(raw), 1: "ok")
	} Else {
		If '$IsValidNum(raw) Quit ..Unavailable(m, unit, "the reported value is not a number")
		Set n = +raw
		Do m.%Set("value", n, "number")
		If kind = "license" {
			Set status = $Select(n >= ..#LICENSECRITICAL: "critical", n >= ..#LICENSEWARNING: "warning", 1: "ok")
		} ElseIf kind = "alerts" {
			Set status = $Select(n > 0: "warning", 1: "ok")
		} Else {
			Set status = "ok"
		}
	}
	Do m.%Set("unit", unit, "string")
	Do m.%Set("status", status, "string")
	Quit m
}

/// Status of a dashboard state text such as LockTable or WriteDaemon.
/// Normal and OK are ok, Warning is a warning, Troubled is critical. A value not seen before is a
/// warning, so a new state is shown rather than hidden as ok.
ClassMethod StateStatus(raw As %String) As %String
{
	Set v = $ZConvert($ZStrip(raw, "<>W"), "L")
	If (v = "normal") || (v = "ok") Quit "ok"
	If v = "warning" Quit "warning"
	If (v = "troubled") || (v = "trouble") Quit "critical"
	Quit "warning"
}

ClassMethod Unavailable(m As %DynamicObject, unit As %String, reason As %String) As %DynamicObject [ Private ]
{
	Do m.%Set("value", "", "null")
	Do m.%Set("unit", unit, "string")
	Do m.%Set("status", "unavailable", "string")
	Do m.%Set("reason", reason, "string")
	Quit m
}

/// Current time as YYYY-MM-DDThh:mm:ssZ.
ClassMethod UtcNow() As %String
{
	Quit $ZDateTime($ZTimeStamp, 3, 7)
}

}
