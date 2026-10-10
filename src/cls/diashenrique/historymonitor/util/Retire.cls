/// Removes what the old pages of 1.x left on an instance (spec 003 FR-005, research R3). Called by IPM after
/// Activate on every install and upgrade, and before Unconfigure on uninstall (module.xml).
/// Idempotent: what is already gone is skipped. Works in the current namespace only, on the explicit names
/// below, so nothing the module did not create is touched, and never a namespace or database (FR-006).
/// The targets are parameters so the test can point them at test-only names (RetireFixture).
Class diashenrique.historymonitor.util.Retire
{

/// Packages that only the old pages used; every class in them is deleted.
Parameter PACKAGES = "diashenrique.historymonitor.dashboard";

/// Single classes: the old utility classes, the removed switch, and the six compiled old pages
/// (other classes of the csp package are left alone).
Parameter CLASSES = "diashenrique.historymonitor.util.metrics,diashenrique.historymonitor.util.Dispatcher,diashenrique.historymonitor.util.Settings,csp.dashboard,csp.dashboardapi,csp.historycspsessions,csp.historydatabase,csp.historylicense,csp.systemprocesses";

/// The old pages' folder under the instance's csp folder (IPM ${cspdir}irismonitor/).
Parameter FOLDER = "irismonitor";

/// The old pages' scratch data and the removed switch.
Parameter GLOBALS = "^IRISMonitor,^diashenrique.historymonitor.Settings";

ClassMethod Folder() As %String
{
	Quit ##class(%File).NormalizeDirectory($SYSTEM.Util.InstallDirectory()_"csp/"_..#FOLDER)
}

/// Removes every leftover that is present. removed returns how many items were removed.
ClassMethod Run(verbose As %Boolean = 1, Output removed As %Integer) As %Status
{
	Set removed = 0, status = $$$OK
	Set packages = $ListFromString(..#PACKAGES), ptr = 0
	While $ListNext(packages, ptr, pkg) {
		Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH ?", pkg_".")
		Kill names
		While rs.%Next() { Set names(rs.Name) = "" }
		Set name = ""
		For {
			Set name = $Order(names(name))
			Quit:name=""
			Set status = $$$ADDSC(status, ..DeleteClass(name, verbose, .removed))
		}
	}
	Set classes = $ListFromString(..#CLASSES), ptr = 0
	While $ListNext(classes, ptr, name) {
		Set status = $$$ADDSC(status, ..DeleteClass(name, verbose, .removed))
	}
	Set dir = ..Folder()
	If ##class(%File).DirectoryExists(dir) {
		If ##class(%File).RemoveDirectoryTree(dir) {
			Set removed = removed + 1
			Write:verbose "Removed old page folder ", dir, !
		} Else {
			Set status = $$$ADDSC(status, $$$ERROR($$$GeneralError, "Could not remove "_dir))
		}
	}
	Set globals = $ListFromString(..#GLOBALS), ptr = 0
	While $ListNext(globals, ptr, gref) {
		// The names come from the parameter above, never from a request.
		If $Data(@gref) {
			Kill @gref
			Set removed = removed + 1
			Write:verbose "Removed ", gref, !
		}
	}
	Quit status
}

ClassMethod DeleteClass(name As %String, verbose As %Boolean, ByRef removed As %Integer) As %Status [ Private ]
{
	Quit:'##class(%Dictionary.ClassDefinition).%ExistsId(name)&&'##class(%Dictionary.CompiledClass).%ExistsId(name) $$$OK
	Set sc = $SYSTEM.OBJ.Delete(name, "-d")
	If $$$ISOK(sc) {
		Set removed = removed + 1
		Write:verbose "Removed class ", name, !
	}
	Quit sc
}

}
