/// Safe replacement for the old `Xecute "do .."_Method_"()"` dispatch.
/// Only methods named in an explicit allow-list can be called from a request.
Class diashenrique.historymonitor.util.Dispatcher
{

/// Calls <var>method</var> of <var>className</var> only when it is in the comma-separated
/// <var>allowed</var> list. Anything else gets an HTTP 400 and nothing is executed.
ClassMethod Run(className As %String, method As %String, allowed As %String) As %Status
{
	If (method '? 1A.AN) || ('$ListFind($ListFromString(allowed, ","), method)) {
		Set %response.Status = "400 Bad Request"
		Write "{""error"":""invalid method""}"
		Quit $$$OK
	}

	Do $ClassMethod(className, method)

	Quit $$$OK
}

}
