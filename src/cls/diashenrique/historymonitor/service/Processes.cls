/// Builds the filtered, sorted, paged process list (user story 3, spec FR-005, data-model ProcessPage,
/// research.md R10).
///
/// Read takes one snapshot of the running processes with the values of the CONTROLPANEL query of
/// %SYS.ProcessQuery, the source the processes page uses today, under stable camelCase names.
/// CONTROLPANEL itself requires %Admin_Manage; Read opens each process of ^$JOB as a %SYS.ProcessQuery
/// object instead and applies the same adjustments the query makes (research.md R10).
/// Build filters, sorts and pages that snapshot. Each request reads a fresh snapshot, so a process
/// that ended since the previous page is simply gone. Nothing is written to a global.
Class diashenrique.historymonitor.service.Processes
{

/// Returned field names, in column order. These are also the allowed sort keys.
ClassMethod Fields() As %List
{
	Quit $ListBuild("job", "pid", "displayPid", "username", "device", "namespace", "routine", "commands", "globals", "state", "clientName", "exeName", "ipAddress", "privateGlobalBlocks", "osUsername", "cpuTime", "parentPid", "elapsedTime")
}

/// Fields holding numbers; the others are text.
ClassMethod Numeric() As %List
{
	Quit $ListBuild("job", "pid", "displayPid", "commands", "globals", "privateGlobalBlocks", "cpuTime", "parentPid")
}

/// Text fields the q parameter searches, plus pid.
ClassMethod Searched() As %List
{
	Quit $ListBuild("pid", "username", "device", "namespace", "routine", "state", "clientName", "exeName", "ipAddress", "osUsername")
}

/// clean holds the values normalized by service.Validate.Processes.
ClassMethod Page(ByRef clean) As %DynamicObject
{
	Do ..Read(.items)
	Quit ..Build(.clean, .items)
}

/// items(n) = one %DynamicObject per process, in job order. Empty values are left out.
ClassMethod Read(Output items)
{
	Kill items
	New $Namespace
	Set $Namespace = "%SYS"
	Set pid = "", n = 0
	For {
		Set pid = $Order(^$JOB(pid))
		Quit:pid=""
		// A process can end between $Order and %OpenId, or while it is read; it is then skipped.
		Try {
			Set p = ##class(%SYS.ProcessQuery).%OpenId(pid)
			If $IsObject(p) Set byJob(+p.JobNumber) = ..Item(p)
		} Catch {
		}
	}
	Set job = ""
	For {
		Set job = $Order(byJob(job), 1, item)
		Quit:job=""
		Set items($Increment(n)) = item
	}
}

/// One process with the adjustments CONTROLPANEL makes (JOBEXAMFetch in %SYS.ProcessQuery).
ClassMethod Item(p As %SYS.ProcessQuery) As %DynamicObject [ Private ]
{
	Set client = p.ClientNodeName
	Set:client="" client = p.ClientIPAddress
	Set ns = p.NameSpace
	If $Extract(ns, 1, 2) = "@@" Set ns = "^^"_$Extract(ns, 3, *)
	Set user = p.UserName
	If $Extract(p.Location, 1, 6) = "Mirror" Set user = p.Location
	Set device = p.CurrentDevice
	If (device [ "|TCP|") && (client '= "") Set device = "|TCP|"_client_":"_$Piece(device, "|", 3)
	If $$$ISWINDOWS {
		Set pidText = p.Pid
		If ((device [ "|TNT|") && (client '= "")) || (($Extract(device, $Length(device) - $Length(pidText) + 1, *) = pidText) && (client '= "") && (device '[ "|TRM|")) {
			Set device = "|TNT|"_client_":"_$Piece($Piece(device, ":", 2), "|")
		}
	}
	Set parent = p.ParentPid
	Set:parent=0 parent = ""

	Set item = {}
	Do ..Put(item, "job", p.JobNumber, 1)
	Do ..Put(item, "pid", p.Pid, 1)
	Do ..Put(item, "displayPid", p.PidExternal, 1)
	Do ..Put(item, "username", user)
	Do ..Put(item, "device", device)
	Do ..Put(item, "namespace", ns)
	Do ..Put(item, "routine", p.Routine)
	Do ..Put(item, "commands", p.CommandsExecuted, 1)
	Do ..Put(item, "globals", p.GlobalReferences, 1)
	Do ..Put(item, "state", p.State)
	Do ..Put(item, "clientName", p.ClientNodeName)
	Do ..Put(item, "exeName", p.ClientExecutableName)
	Do ..Put(item, "ipAddress", p.ClientIPAddress)
	Do ..Put(item, "privateGlobalBlocks", p.PrivateGlobalBlockCount, 1)
	Do ..Put(item, "osUsername", p.OSUserName)
	Do ..Put(item, "cpuTime", p.CPUTime, 1)
	Do ..Put(item, "parentPid", parent, 1)
	Do ..Put(item, "elapsedTime", ##class(%SYS.ProcessQuery).ElapsedTime(p.StartTimeUTC))
	Quit item
}

/// Sets field unless value is empty; numbers leave as JSON numbers.
ClassMethod Put(item As %DynamicObject, field As %String, value As %String, numeric As %Boolean = 0) [ Private ]
{
	Quit:value=""
	If numeric && $IsValidNum(value) {
		Do item.%Set(field, +value, "number")
	} Else {
		Do item.%Set(field, value, "string")
	}
}

/// Filters, sorts and pages items(n). A field a process does not have sorts after every value, in
/// either direction; ties are broken by job number.
ClassMethod Build(ByRef clean, ByRef items) As %DynamicObject
{
	Set field = $Get(clean("sortField"), "job"), desc = +$Get(clean("sortDesc"))
	Set numeric = $ListFind(..Numeric(), field)
	Set searched = ..Searched(), needle = $ZConvert($Get(clean("q")), "L")
	Set total = 0, n = ""
	For {
		Set n = $Order(items(n), 1, item)
		Quit:n=""
		If $Data(clean("namespace")) && (item.namespace '= clean("namespace")) Continue
		If $Data(clean("user")) && (item.username '= clean("user")) Continue
		If $Data(clean("state")) && (item.state '= clean("state")) Continue
		If needle '= "" {
			Set hit = 0
			For i = 1:1:$ListLength(searched) {
				If $ZConvert(item.%Get($List(searched, i)), "L") [ needle Set hit = 1 Quit
			}
			Continue:'hit
		}
		Set total = total + 1
		Set job = +item.job, v = item.%Get(field)
		If v = "" {
			Set missing(job, n) = ""
		} Else {
			Set present($Select(numeric: +v, 1: " "_$ZConvert(v, "U")), job, n) = ""
		}
	}

	Set page = clean("page"), size = clean("pageSize")
	Set first = ((page - 1) * size) + 1, last = first + size - 1
	Set list = [], pos = 0, key = ""
	For {
		Set key = $Order(present(key), $Select(desc: -1, 1: 1))
		Quit:key=""
		Do ..Take(.present, key, .items, .pos, first, last, list)
	}
	Do ..Take(.missing, "", .items, .pos, first, last, list)

	Set body = {"items": (list)}
	Do body.%Set("total", total, "number")
	Do body.%Set("page", page, "number")
	Do body.%Set("pageSize", size, "number")
	If last < total Do body.%Set("next", (page + 1)_"", "string")
	Quit body
}

/// Walks the job and item subscripts under one sort key (or the top level of missing when key is
/// "") in job order, and pushes the items whose position falls inside first..last.
ClassMethod Take(ByRef index, key As %String, ByRef items, ByRef pos As %Integer, first As %Integer, last As %Integer, list As %DynamicArray) [ Private ]
{
	Set job = ""
	For {
		Set job = $Select(key = "": $Order(index(job)), 1: $Order(index(key, job)))
		Quit:job=""
		Set n = ""
		For {
			Set n = $Select(key = "": $Order(index(job, n)), 1: $Order(index(key, job, n)))
			Quit:n=""
			Set pos = pos + 1
			If (pos >= first) && (pos <= last) Do list.%Push(items(n))
		}
	}
}

}
