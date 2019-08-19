Class VAR.infra.dashboard.SystemProcesses Extends %CSP.Page
{

Parameter CHARSET = "utf-8";

ClassMethod OnPage() As %Status
{
	#dim %request As %CSP.Request
	#dim %response As %CSP.Response
	
	Set Method 	= $Get(%request.Data("method",1))

	xecute "do .."_Method_"()"
	
	Quit $$$OK
}

/// do ##class(VAR.infra.dashboard.SystemProcesses).getProcessesInfo()
ClassMethod getProcessesInfo() As %Status
{
  	
    new $namespace
	set $namespace = "%SYS"

	set tSC = $System.Status.OK()
	set arrayProcInfo = []

    try {

		set oRS = ##class(%SQL.Statement).%New()
        
        set tSC = oRS.%PrepareClassQuery("%SYS.ProcessQuery", "CONTROLPANEL")
       
        quit:$System.Status.IsError(tSC)
        
        set intcolumnCount = oRS.%Metadata.columnCount
        
        set result = oRS.%Execute()
        
        if (result.%SQLCODE '< 0) {
	        while result.%Next() {
	        	set json = {}
	        	for i=1:1:intcolumnCount {
		        	// Skipping : Can Be Examined, Can Be Suspended, Can Be Terminated, Can Receive Broadcast
		        	if ((i > 13) && (i < 19)) {
			        	continue
		        	}
					do json.%Set(oRS.%Metadata.columns.GetAt(i).colName,result.%GetData(i))
				}
				do arrayProcInfo.%Push(json)
            }
        } else {
            throw ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
	    
	    
    } catch (oException) {
        set tSC = oException.AsStatus()
    }
    
    write arrayProcInfo.%ToJSON() 
    
    quit tSC
}

}
