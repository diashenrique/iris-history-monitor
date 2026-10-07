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
	// One short line per failed method, then the totals, so a tail of the log always shows them.
	For i = 1:1:$ListLength(names) Write "FAILED_METHOD ", $List(names, i), !
	Write "TEST_METHODS=", total, " FAILED_COUNT=", failed, !
	Quit $$$OK
}

}
