Class diashenrique.historymonitor.dashboard.SystemProcesses Extends %CSP.Page
{

Parameter CHARSET = "utf-8";

ClassMethod OnPage() As %Status
{
	#dim %request As %CSP.Request
	#dim %response As %CSP.Response

	Set Method = $Get(%request.Data("method",1))

	Xecute "do .."_Method_"()"

	Quit $$$OK
}

/// do ##class(diashenrique.historymonitor.dashboard.SystemProcesses).getProcessesInfo()
ClassMethod getProcessesInfo() As %Status
{

    New $Namespace
	Set $Namespace = "%SYS"

	Set tSC = $System.Status.OK()
	Set arrayProcInfo = []

    Try {

		Set oRS = ##class(%SQL.Statement).%New()

        Set tSC = oRS.%PrepareClassQuery("%SYS.ProcessQuery", "CONTROLPANEL")

        Quit:$System.Status.IsError(tSC)

        Set intcolumnCount = oRS.%Metadata.columnCount

        Set result = oRS.%Execute()

        If (result.%SQLCODE '< 0) {
	        While result.%Next() {
	        	Set json = { }
	        	For i=1:1:intcolumnCount {
		        	// Skipping : Can Be Examined, Can Be Suspended, Can Be Terminated, Can Receive Broadcast
		        	If ((i > 13) && (i < 19)) {
			        	Continue
		        	}
					Do json.%Set(oRS.%Metadata.columns.GetAt(i).colName,result.%GetData(i))
				}
				Do arrayProcInfo.%Push(json)
            }
        }
        Else {
            Throw ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }


    }
    Catch (oException) {
        Set tSC = oException.AsStatus()
    }

    Write arrayProcInfo.%ToJSON() 

    Quit tSC
}

}
