/// CI entry point: runs the %UnitTest suite and prints a machine-readable summary.
Class diashenrique.historymonitor.test.Runner
{

ClassMethod Run() As %Status
{
	Set ^UnitTestRoot = "/home/irisowner/repo/src/cls"
	Do ##class(%UnitTest.Manager).RunTest("diashenrique/historymonitor/test", "/nodelete/noload")

	Set failed = 0, total = 0
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Status, Name, TestCase->Name AS CaseName FROM %UnitTest_Result.TestMethod WHERE TestCase->TestSuite->TestInstance = (SELECT MAX(ID) FROM %UnitTest_Result.TestInstance)")
	Set names = ""
	While rs.%Next() {
		Set total = total + 1
		If 'rs.Status {
			Set failed = failed + 1
			Set names = names_$ListBuild(rs.CaseName_":"_rs.Name)
		}
	}
	// A test case whose OnBeforeAllTests fails runs no method at all, so it never shows above. Count
	// every failed case that has no failed method as one failure of its own.
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name, Status FROM %UnitTest_Result.TestCase WHERE TestSuite->TestInstance = (SELECT MAX(ID) FROM %UnitTest_Result.TestInstance)")
	Set cases = ""
	While rs.%Next() {
		Continue:rs.Status
		Set seen = 0
		For i = 1:1:$ListLength(names) If $Piece($List(names, i), ":", 1) = rs.Name Set seen = 1 Quit
		If 'seen Set failed = failed + 1, cases = cases_$ListBuild(rs.Name)
	}
	// One short line per failed method or case, then the totals, so a tail of the log always shows them.
	// Start on a fresh line: the %UnitTest output can end without one, which hid the first name from grep.
	Write !
	For i = 1:1:$ListLength(names) Write "FAILED_METHOD ", $List(names, i), !
	For i = 1:1:$ListLength(cases) Write "FAILED_CASE ", $List(cases, i), " (no method ran; see OnBeforeAllTests)", !
	Write "TEST_METHODS=", total, " FAILED_COUNT=", failed, !
	Quit $$$OK
}

}
