/// Cleanup of what 1.x left (spec 003 FR-005, FR-006, US2; research R3). Runs util.Retire through
/// RetireFixture, whose targets are test-only names: leftovers of every kind are seeded, Run() must remove
/// them, keep everything else, and remove nothing on a second run.
Class diashenrique.historymonitor.test.api.RetireTest Extends %UnitTest.TestCase
{

Parameter R = "diashenrique.historymonitor.test.api.RetireFixture";

/// Survives: same package as the page classes, but not one of them.
Parameter KEEPCLASS = "diashenrique.historymonitor.test.retirecsp.KeepMe";

Method OnBeforeOneTest(testname As %String) As %Status
{
	Do ..Clean()
	For c = "diashenrique.historymonitor.test.retireold.dashboard", "diashenrique.historymonitor.test.retireold.license", ..#KEEPCLASS {
		Set sc = ..Stub(c)
		Quit:$$$ISERR(sc)
	}
	Quit:$$$ISERR(sc) sc
	Set list = $ListFromString($Parameter(..#R, "CLASSES"))
	Set ptr = 0
	While $ListNext(list, ptr, c) {
		Set sc = ..Stub(c)
		Quit:$$$ISERR(sc)
	}
	Quit:$$$ISERR(sc) sc
	Set dir = $ClassMethod(..#R, "Folder")
	Do ##class(%File).CreateDirectoryChain(dir_"resources")
	Set f = ##class(%Stream.FileCharacter).%New()
	Set f.Filename = dir_"resources/old.css"
	Do f.Write("body{}"), f.%Save()
	Set ^HMRetireTestScratch("grid", 1) = "x"
	Set ^HMRetireTestSettings("interfaceEnabled") = 0
	Set ^HMRetireKeep = "keep"
	Quit $$$OK
}

Method OnAfterOneTest(testname As %String) As %Status
{
	Do ..Clean()
	Quit $$$OK
}

Method TestRemovesEveryLeftover()
{
	Do $$$AssertStatusOK($ClassMethod(..#R, "Run", 0), "Run returns OK")
	For c = "diashenrique.historymonitor.test.retireold.dashboard", "diashenrique.historymonitor.test.retireold.license" {
		Do $$$AssertNotTrue(..Exists(c), "class of the old package removed: "_c)
	}
	Set list = $ListFromString($Parameter(..#R, "CLASSES")), ptr = 0
	While $ListNext(list, ptr, c) {
		Do $$$AssertNotTrue(..Exists(c), "listed class removed: "_c)
	}
	Do $$$AssertNotTrue(##class(%File).DirectoryExists($ClassMethod(..#R, "Folder")), "page folder removed")
	Do $$$AssertNotTrue($Data(^HMRetireTestScratch), "scratch data removed")
	Do $$$AssertNotTrue($Data(^HMRetireTestSettings), "switch value removed")
}

Method TestKeepsWhatTheModuleDidNotCreate()
{
	Set ns = $Namespace
	Do $$$AssertStatusOK($ClassMethod(..#R, "Run", 0))
	Do $$$AssertTrue(..Exists(..#KEEPCLASS), "a class of the same package that is not a listed page stays")
	Do $$$AssertEquals($Get(^HMRetireKeep), "keep", "an unrelated global stays")
	Do $$$AssertEquals($Namespace, ns, "still in the same namespace")
	Do $$$AssertTrue(##class(%SYS.Namespace).Exists(ns), "the namespace stays")
	Do $$$AssertTrue(##class(%File).DirectoryExists(##class(%File).ParentDirectoryName($ClassMethod(..#R, "Folder"))), "the csp folder itself stays")
}

Method TestSecondRunRemovesNothing()
{
	Do $$$AssertStatusOK($ClassMethod(..#R, "Run", 0))
	Set removed = ""
	Do $$$AssertStatusOK($ClassMethod(..#R, "Run", 0, .removed), "second run returns OK")
	Do $$$AssertEquals(removed, 0, "second run removes nothing")
}

Method TestRealTargetsAreTheOldParts()
{
	// The real names are what 1.x left (data-model.md); checked here so a typo cannot slip through.
	Set R = "diashenrique.historymonitor.util.Retire"
	Do $$$AssertEquals($Parameter(R, "PACKAGES"), "diashenrique.historymonitor.dashboard")
	Set classes = $Parameter(R, "CLASSES")
	For c = "diashenrique.historymonitor.util.metrics", "diashenrique.historymonitor.util.Dispatcher", "diashenrique.historymonitor.util.Settings", "csp.dashboard", "csp.dashboardapi", "csp.historycspsessions", "csp.historydatabase", "csp.historylicense", "csp.systemprocesses" {
		Do $$$AssertTrue((","_classes_",") [ (","_c_","), "real target "_c)
	}
	Do $$$AssertEquals($Length(classes, ","), 9, "exactly nine single classes")
	Do $$$AssertEquals($Parameter(R, "GLOBALS"), "^IRISMonitor,^diashenrique.historymonitor.Settings")
	Do $$$AssertEquals($ClassMethod(R, "Folder"), ##class(%File).NormalizeDirectory($SYSTEM.Util.InstallDirectory()_"csp/irismonitor"))
}

ClassMethod Stub(name As %String) As %Status
{
	Set def = ##class(%Dictionary.ClassDefinition).%New()
	Set def.Name = name
	Set def.ProcedureBlock = 1
	Set sc = def.%Save()
	Quit:$$$ISERR(sc) sc
	Quit $SYSTEM.OBJ.Compile(name, "-d")
}

ClassMethod Exists(name As %String) As %Boolean
{
	Quit ##class(%Dictionary.ClassDefinition).%ExistsId(name) || ##class(%Dictionary.CompiledClass).%ExistsId(name)
}

ClassMethod Clean()
{
	For pkg = "diashenrique.historymonitor.test.retireold", "diashenrique.historymonitor.test.retireutil", "diashenrique.historymonitor.test.retirecsp" {
		Do $SYSTEM.OBJ.DeletePackage(pkg, "-d")
	}
	Do ##class(%File).RemoveDirectoryTree($ClassMethod(..#R, "Folder"))
	Kill ^HMRetireTestScratch, ^HMRetireTestSettings, ^HMRetireKeep
}

}
