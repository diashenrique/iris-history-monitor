/// Keeps the routes, the contract and the tests in step (task T022, spec SC-003, constitution III).
/// Every path and method of contracts/openapi.json must have a route in api.Dispatch, every route must be
/// in the contract, and every route must have a contract test class and a call in HttpAuthTest
/// (which also checks each response against its schema over HTTP).
Class diashenrique.historymonitor.test.api.ContractCoverageTest Extends %UnitTest.TestCase
{

Parameter D = "diashenrique.historymonitor.api.Dispatch";

/// The contract test class of each operation.
ClassMethod ContractTestClass(operationId As %String) As %String
{
	Quit $Case(operationId, "getOverview": "OverviewTest", "getHistory": "HistoryTest", "listProcesses": "ProcessesTest", : "")
}

/// routes(contract path, method in lower case) = "" for every Route of the UrlMap, with :name written
/// as {name} the way the contract writes it.
ClassMethod Routes(Output routes)
{
	Kill routes
	Set xdata = ##class(%Dictionary.CompiledXData).%OpenId(..#D_"||UrlMap")
	Quit:'$IsObject(xdata)
	Set text = xdata.Data.Read(100000), pos = 1
	For {
		Set found = $Locate(text, "<Route\s+Url=""[^""]+""\s+Method=""[^""]+""", pos, end, match)
		Quit:found=0
		Set pos = end
		Set url = $Piece($Piece(match, "Url=""", 2), """", 1), method = $Piece($Piece(match, "Method=""", 2), """", 1)
		Set path = "", i = 0
		For i = 1:1:$Length(url, "/") {
			Set seg = $Piece(url, "/", i)
			Set:$Extract(seg)=":" seg = "{"_$Extract(seg, 2, *)_"}"
			Set path = path_$Select(i = 1: "", 1: "/")_seg
		}
		Set routes(path, $ZConvert(method, "L")) = ""
	}
}

/// The contract path a request path such as /history/license?x=1 belongs to, or "".
ClassMethod PathFor(request As %String, contract As %DynamicObject) As %String
{
	Set req = $Piece(request, "?", 1)
	Set it = contract.paths.%GetIterator()
	While it.%GetNext(.path) {
		If $Length(path, "/") '= $Length(req, "/") Continue
		Set ok = 1
		For i = 1:1:$Length(path, "/") {
			Set seg = $Piece(path, "/", i)
			If ($Extract(seg) '= "{") && (seg '= $Piece(req, "/", i)) Set ok = 0 Quit
		}
		If ok Return path
	}
	Quit ""
}

Method TestEveryContractOperationHasARoute()
{
	Do ..Routes(.routes)
	Set contract = ##class(diashenrique.historymonitor.test.api.ContractHelper).Contract()
	Set it = contract.paths.%GetIterator()
	While it.%GetNext(.path, .item) {
		Set mit = item.%GetIterator()
		While mit.%GetNext(.method) {
			Do $$$AssertEquals($Data(routes(path, method)), 1, $ZConvert(method, "U")_" "_path_" has a route")
		}
	}
}

Method TestEveryRouteIsInTheContract()
{
	Do ..Routes(.routes)
	Do $$$AssertTrue($Data(routes) > 0, "routes found in the UrlMap")
	Set contract = ##class(diashenrique.historymonitor.test.api.ContractHelper).Contract()
	Set path = ""
	For {
		Set path = $Order(routes(path))
		Quit:path=""
		Set method = ""
		For {
			Set method = $Order(routes(path, method))
			Quit:method=""
			Set op = ""
			If $IsObject(contract.paths.%Get(path)) Set op = contract.paths.%Get(path).%Get(method)
			Do $$$AssertTrue($IsObject(op), $ZConvert(method, "U")_" "_path_" is in the contract")
		}
	}
}

Method TestEveryOperationHasAContractTestAndAnHttpTest()
{
	Set contract = ##class(diashenrique.historymonitor.test.api.ContractHelper).Contract()
	Set http = ##class(diashenrique.historymonitor.test.api.HttpAuthTest).Routes()
	For i = 1:1:$ListLength(http) {
		Set path = ..PathFor($List(http, i), contract)
		Set:path'="" covered(path) = ""
	}
	Set it = contract.paths.%GetIterator()
	While it.%GetNext(.path, .item) {
		Set mit = item.%GetIterator()
		While mit.%GetNext(.method, .op) {
			Set cls = ..ContractTestClass(op.operationId)
			Do $$$AssertNotEquals(cls, "", op.operationId_" has a contract test class")
			Do $$$AssertTrue(##class(%Dictionary.CompiledClass).%ExistsId("diashenrique.historymonitor.test.api."_cls), op.operationId_": "_cls_" exists")
			Do $$$AssertEquals($Data(covered(path)), 1, path_" is called over HTTP in HttpAuthTest")
		}
	}
}

}
