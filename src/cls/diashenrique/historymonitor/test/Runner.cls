/// CI entry point: runs the %UnitTest suite and prints a machine-readable summary.
Class diashenrique.historymonitor.test.Runner
{

ClassMethod Run() As %Status
{
	Set ^UnitTestRoot = "/home/irisowner/repo/src/cls"
	Do ##class(%UnitTest.Manager).RunTest("diashenrique/historymonitor/test", "/nodelete/noload")

	Set failed = 0, total = 0
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Status FROM %UnitTest_Result.TestMethod WHERE TestCase->TestSuite->TestInstance = (SELECT MAX(ID) FROM %UnitTest_Result.TestInstance)")
	While rs.%Next() {
		Set total = total + 1
		If 'rs.Status Set failed = failed + 1
	}
	Write "TEST_METHODS=", total, " FAILED_COUNT=", failed, !
	Quit $$$OK
}

}
