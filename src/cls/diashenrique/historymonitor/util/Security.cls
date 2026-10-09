/// Creates and removes the resource and role that gate the History Monitor API (spec FR-008).
/// The role holds Use on the resource; the web application requires the resource (task T008).
/// It also holds Read on %DB_IRISSYS, because the services read SYS.Stats.Dashboard and other %SYS
/// classes; without it the overview is all unavailable for a user who is not an administrator.
/// Finally it may SELECT the System Monitor history tables the history service reads, and nothing else.
Class diashenrique.historymonitor.util.Security
{

Parameter RESOURCE = "HistoryMonitorRead";

Parameter ROLE = "HistoryMonitorViewer";

/// Read on the system database, needed to switch to %SYS. Read only: nothing is written there.
Parameter SYSTEMREAD = "%DB_IRISSYS:R";

/// The SYS_History tables service.History reads. The role gets SELECT on these only.
Parameter HISTORYTABLES = "SysData,SysData_DB,Hourly,Hourly_Sys,Hourly_DB,Daily,Daily_Sys,Daily_DB";

/// Creates the resource and the role if they do not exist. Safe to call more than once.
/// do ##class(diashenrique.historymonitor.util.Security).Setup()
ClassMethod Setup(resource As %String = "HistoryMonitorRead", role As %String = "HistoryMonitorViewer") As %Status
{
	New $Namespace
	Set $Namespace = "%SYS"
	Set sc = $$$OK

	Try {
		If '##class(Security.Resources).Exists(resource) {
			Set sc = ##class(Security.Resources).Create(resource, "IRIS History Monitor API read access", "")
			Quit:$$$ISERR(sc)
		}
		Set wanted = resource_":U,"_..#SYSTEMREAD
		If '##class(Security.Roles).Exists(role) {
			Set sc = ##class(Security.Roles).Create(role, "Can read the IRIS History Monitor API", wanted)
			Quit:$$$ISERR(sc)
		} Else {
			// A role created by an older version may lack a grant; add what is missing, keep the rest.
			Set sc = ##class(Security.Roles).Get(role, .props)
			Quit:$$$ISERR(sc)
			Set have = $Get(props("Resources")), add = ""
			For i = 1:1:$Length(wanted, ",") {
				Set grant = $Piece(wanted, ",", i)
				If '..Holds(have, $Piece(grant, ":", 1), $Piece(grant, ":", 2)) Set add = add_$ListBuild(grant)
			}
			If add '= "" {
				Set props("Resources") = $Select(have = "": "", 1: have_",")_$ListToString(add, ",")
				Set sc = ##class(Security.Roles).Modify(role, .props)
				Quit:$$$ISERR(sc)
			}
		}
		// SQL privileges live in the namespace of the tables, %SYS. Granting again is harmless.
		Set tables = ""
		For i = 1:1:$Length(..#HISTORYTABLES, ",") Set tables = tables_$Select(i > 1: ",", 1: "")_"SYS_History."_$Piece(..#HISTORYTABLES, ",", i)
		Set sc = $SYSTEM.SQL.Security.GrantPrivilege("SELECT", tables, "TABLE", role)
	}
	Catch ex {
		Set sc = ex.AsStatus()
	}

	Quit sc
}

/// Removes the role first, then the resource. Safe when either is already gone.
ClassMethod Teardown(resource As %String = "HistoryMonitorRead", role As %String = "HistoryMonitorViewer") As %Status
{
	New $Namespace
	Set $Namespace = "%SYS"
	Set sc = $$$OK

	Try {
		If ##class(Security.Roles).Exists(role) {
			Set sc = ##class(Security.Roles).Delete(role)
			Quit:$$$ISERR(sc)
		}
		If ##class(Security.Resources).Exists(resource) {
			Set sc = ##class(Security.Resources).Delete(resource)
		}
	}
	Catch ex {
		Set sc = ex.AsStatus()
	}

	Quit sc
}

/// True when the comma list of resource:permissions grants every letter of perm on name.
ClassMethod Holds(list As %String, name As %String, perm As %String) As %Boolean
{
	For i = 1:1:$Length(list, ",") {
		Set item = $Piece(list, ",", i)
		If $Piece(item, ":", 1) '= name Continue
		Set ok = 1
		For j = 1:1:$Length(perm) { If $Piece(item, ":", 2) '[ $Extract(perm, j) Set ok = 0 }
		If ok Return 1
	}
	Quit 0
}

}
