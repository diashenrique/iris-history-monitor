/// Whether the instance is recording history, and how long it keeps each granularity (spec 004 FR-001,
/// FR-002; research R1-R3). Reads only: the System Monitor's own settings and tables in %SYS. It never
/// changes the collector or its retention (FR-006, owner's option A); "Turning on history collection" in
/// the README is for an administrator.
Class diashenrique.historymonitor.service.Collection
{

/// The collector part that records the three History metrics (system usage, SYS.History.SysData).
Parameter GROUP = "%Monitor||%Monitor.System.HistorySys";

/// Sample interval assumed when the instance does not say (the IRIS default for system usage).
Parameter DEFAULTINTERVAL = 300;

/// recording, stale or off. lastKey and nowKey are UTC seconds since the $H epoch ("" when no sample).
ClassMethod Decide(configured As %Boolean, lastKey As %String, nowKey As %Integer, interval As %String) As %String
{
	Quit:'configured "off"
	Quit:lastKey="" "stale"
	Set interval = $Select(+interval > 0: +interval, 1: ..#DEFAULTINTERVAL)
	Quit $Select(nowKey - lastKey > (3 * interval): "stale", 1: "recording")
}

/// The body of GET /history-collection (contract HistoryCollection).
ClassMethod Response() As %DynamicObject
{
	Do ..Read(.configured, .interval, .running, .lastKey, .detailDays, .hourlyDays)
	Set H = "diashenrique.historymonitor.service.History"
	Set body = {}
	Do body.%Set("state", ..Decide(configured, lastKey, $ClassMethod(H, "NowKey"), interval))
	Do body.%Set("running", $Select(running = "": "", 1: running), $Select(running = "": "null", 1: "boolean"))
	Do body.%Set("lastSample", $Select(lastKey = "": "", 1: $ClassMethod(H, "Iso", lastKey)), $Select(lastKey = "": "null", 1: "string"))
	Do body.%Set("intervalSeconds", $Select(+interval > 0: +interval, 1: ""), $Select(+interval > 0: "number", 1: "null"))
	Set retention = {}
	Do retention.%Set("5min", ..Days(detailDays))
	Do retention.%Set("hourly", ..Days(hourlyDays))
	Do retention.%Set("daily", {"kind": "indefinite", "days": null})
	Do body.%Set("retention", retention)
	Quit body
}

/// Reads everything in %SYS; each read on its own, so one refusal leaves the rest. SetPurge("") returns the
/// setting and changes nothing (its documentation).
ClassMethod Read(Output configured, Output interval, Output running, Output lastKey, Output detailDays, Output hourlyDays) [ Private ]
{
	Set configured = 0, (interval, running, lastKey, detailDays, hourlyDays) = ""
	New $Namespace
	Set $Namespace = "%SYS"
	Try {
		Set group = ##class(%Monitor.ItemGroup).%OpenId(..#GROUP)
		Set configured = $IsObject(group) && group.Activated
		Set:$IsObject(group) interval = group.SampInterval
	} Catch {}
	// The collector process, found the way service.Processes reads processes. Through SQL on
	// %SYS.ProcessQuery the viewer role did not see it (spec 004 research R3).
	Try {
		Set running = 0, pid = ""
		For {
			Set pid = $Order(^$JOB(pid))
			Quit:pid=""
			Try {
				Set p = ##class(%SYS.ProcessQuery).%OpenId(pid)
				If $IsObject(p) && ($Piece(p.Routine, " ") = "%MONAPP") Set running = 1
			} Catch {}
			Quit:running
		}
	} Catch { Set running = "" }
	Try {
		Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT MAX(ZDATE * 86400 + ZTIME) AS K FROM SYS_History.SysData")
		Set:rs.%Next() lastKey = rs.K
	} Catch {}
	Try { Set detailDays = ##class(SYS.History.PerfData).SetPurge("") } Catch {}
	Try { Set hourlyDays = ##class(SYS.History.Hourly).SetPurge("") } Catch {}
}

/// A retention entry from a day count ("" or 0 when it could not be read).
ClassMethod Days(days As %String) As %DynamicObject [ Private ]
{
	Quit:+days>0 {"kind": "days", "days": (+days)}
	Quit {"kind": "unknown", "days": null}
}

}
