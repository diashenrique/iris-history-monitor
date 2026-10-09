/// Creates and removes the resource and role that gate the History Monitor API (spec FR-008).
/// The role holds Use on the resource; the web application requires the resource (task T008).
Class diashenrique.historymonitor.util.Security
{

Parameter RESOURCE = "HistoryMonitorRead";

Parameter ROLE = "HistoryMonitorViewer";

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
		If '##class(Security.Roles).Exists(role) {
			Set sc = ##class(Security.Roles).Create(role, "Can read the IRIS History Monitor API", resource_":U")
		}
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

}
