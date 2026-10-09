/// Test data for the history tests (tasks T014, T015). Writes real System Monitor rows in February 2001,
/// far from any real sample, and removes them again. Test-only: not shipped in module.xml.
///
/// ZDATE and ZTIME are the UTC key of every SYS.History row (DateTime is local time), so the rows are
/// created by UTC key and the expected API timestamps are those keys.
///   5-minute (SysData): 2001-02-03 10:00 to 10:55 UTC, 12 rows. LicUsedLocal = i, CSPSession = 2*i
///     (i = 0..11) except row 6, whose CSPSession is empty. Databases HMTESTDB (100+i) and HMOTHERDB (50).
///   Hourly: 2001-02-03 08:00 to 13:00 UTC, 6 rows. Sys Avg = h, Max = h + 0.5, StDev = 9 (h = hour).
///     Databases HMTESTDB_Avg/_Max/_StDev (200 + h, 210 + h, 1) and HMOTHERDB_Max (60).
///   Daily: 2001-02-01 to 2001-02-05 at 00:00 UTC, 5 rows. Sys Avg = d, Max = d + 0.5 (d = day of month).
///     Databases HMTESTDB_Max (300 + d) and HMOTHERDB_Max (70).
Class diashenrique.historymonitor.test.api.HistoryFixture
{

/// $H date of 2001-02-01.
ClassMethod Day1() As %Integer
{
	Quit $ZDateH("2001-02-01", 3)
}

ClassMethod Create() As %Status
{
	Set sc = ..Remove()
	Quit:$$$ISERR(sc) sc
	New $Namespace
	Set $Namespace = "%SYS"
	Set day3 = ..Day1() + 2
	Try {
		For i = 0:1:11 {
			Set row = ##class(SYS.History.SysData).%New()
			Do ..Key(row, day3, 36000 + (i * 300))
			Set row.Sys.LicUsedLocal = i
			Set row.Sys.CSPSession = $Select(i = 6: "", 1: 2 * i)
			Do row.DB.SetAt(..Db(100 + i), "HMTESTDB")
			Do row.DB.SetAt(..Db(50), "HMOTHERDB")
			$$$ThrowOnError(row.%Save())
		}
		For h = 8:1:13 {
			Set row = ##class(SYS.History.Hourly).%New()
			Do ..Key(row, day3, h * 3600)
			Do row.Sys.SetAt(..Usage(h, 2 * h), "Avg")
			Do row.Sys.SetAt(..Usage(h + 0.5, 2 * h + 1), "Max")
			Do row.Sys.SetAt(..Usage(9, 9), "StDev")
			Do row.DB.SetAt(..Db(200 + h), "HMTESTDB_Avg")
			Do row.DB.SetAt(..Db(210 + h), "HMTESTDB_Max")
			Do row.DB.SetAt(..Db(1), "HMTESTDB_StDev")
			Do row.DB.SetAt(..Db(60), "HMOTHERDB_Max")
			$$$ThrowOnError(row.%Save())
		}
		For d = 1:1:5 {
			Set row = ##class(SYS.History.Daily).%New()
			Do ..Key(row, ..Day1() + d - 1, 0)
			Do row.Sys.SetAt(..Usage(d, 3 * d), "Avg")
			Do row.Sys.SetAt(..Usage(d + 0.5, 3 * d + 1), "Max")
			Do row.DB.SetAt(..Db(300 + d), "HMTESTDB_Max")
			Do row.DB.SetAt(..Db(70), "HMOTHERDB_Max")
			$$$ThrowOnError(row.%Save())
		}
	} Catch ex {
		Set sc = ex.AsStatus()
	}
	Quit sc
}

/// Deletes every SysData, Hourly and Daily row of February 2001 (only fixture rows live there).
ClassMethod Remove() As %Status
{
	New $Namespace
	Set $Namespace = "%SYS"
	Set sc = $$$OK
	Try {
		For table = "SysData", "Hourly", "Daily" {
			Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM SYS_History."_table_" WHERE ZDATE BETWEEN ? AND ?", ..Day1(), ..Day1() + 27)
			While rs.%Next() {
				$$$ThrowOnError($ClassMethod("SYS.History."_table, "%DeleteId", rs.ID))
			}
		}
	} Catch ex {
		Set sc = ex.AsStatus()
	}
	Quit sc
}

ClassMethod Key(row, date As %Integer, seconds As %Integer) [ Private ]
{
	Set row.ZDATE = date, row.ZTIME = seconds
	Set row.DateTime = $ZDateTime(date_","_seconds, 3)
}

ClassMethod Usage(lic, csp) As %RegisteredObject [ Private ]
{
	Set u = ##class(SYS.History.SystemUsage).%New()
	Set u.LicUsedLocal = lic, u.CSPSession = csp
	Quit u
}

ClassMethod Db(size) As %RegisteredObject [ Private ]
{
	Set db = ##class(SYS.History.Database).%New()
	Set db.FileSize = size, db.FreeSpace = 0
	Quit db
}

}
