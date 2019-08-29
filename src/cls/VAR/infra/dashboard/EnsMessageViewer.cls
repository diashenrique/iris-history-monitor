Class VAR.infra.dashboard.EnsMessageViewer Extends %CSP.Page
{

Parameter CHARSET = "utf-8";

ClassMethod OnPage() As %Status
{
	#dim %request As %CSP.Request
	#dim %response As %CSP.Response
	
	SET Method 	= $Get(%request.Data("method",1))

	XECUTE "do .."_Method_"()"
	
	QUIT $$$OK
}

/// do ##class(VAR.infra.dashboard.EnsMessageViewer).getMessageHeader()
ClassMethod getMessageHeader() As %Status
{
  	
  	SET selectedNamespace = ""
    SET selectedNamespace = $get(%request.Data("pNamespace",1))
    
    NEW $namespace

    IF (selectedNamespace '= "") {
		SET $namespace = selectedNamespace    
    } ELSE {
	    SET $namespace = "ENSEMBLE"
	}

	SET tSC = $System.Status.OK()
	SET arrayMessage = []

    TRY {

		SET oRS = ##class(%SQL.Statement).%New()
                
        SET sql = "SELECT TOP 200 ID, Banked, BusinessProcessId, CorrespondingMessageId, Description, ErrorStatus, %EXTERNAL(Invocation) as Invocation, "_
        		  "CASE IsError WHEN 1 THEN 'Error' ELSE 'OK' END As Error, "_
        		  "MessageBodyClassName, MessageBodyId, %EXTERNAL(Priority) as Priority, Resent, ReturnQueueName, "_
        		  "SessionId, %EXTERNAL(SourceBusinessType) as SourceBusinessType, SourceConfigName, %EXTERNAL(Status) as Status, "_
        		  "SuperSession, %EXTERNAL(TargetBusinessType) as TargetBusinessType, TargetConfigName, TargetQueueName, "_
        		  "{fn LEFT(%EXTERNAL(TimeCreated),10 )} As DateCreated, {fn RIGHT(%EXTERNAL(TimeCreated),12 )} As TimeCreated, "_
        		  "{fn LEFT(%EXTERNAL(TimeProcessed),10 )} As DateProcessed, {fn RIGHT(%EXTERNAL(TimeProcessed),12 )} As TimeProcessed,  "_
        		  "%EXTERNAL(Type) as Type "_
        		  "FROM Ens.MessageHeader "_
        		  "WHERE SessionId = %ID "_
        		  "ORDER BY SessionId Desc "
		
        SET tSC = oRS.%Prepare(sql)
       
        QUIT:$System.Status.IsError(tSC)
        
        SET intcolumnCount = oRS.%Metadata.columnCount
        
        SET result = oRS.%Execute()
        
        SET count = 0
        
        IF (result.%SQLCODE '< 0) {
	        WHILE result.%Next() {
	        	SET json = {}
	        	FOR i=1:1:intcolumnCount {
					DO json.%Set(oRS.%Metadata.columns.GetAt(i).colName,result.%GetData(i))
				}
				DO arrayMessage.%Push(json)
            }
        } ELSE {
            THROW ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
    } CATCH (oException) {
        SET tSC = oException.AsStatus()
    }
    
    WRITE arrayMessage.%ToJSON() 
    
    QUIT tSC
}

/// do ##class(VAR.infra.dashboard.EnsMessageViewer).getEnsembleNamespace()
ClassMethod getEnsembleNamespace() As %Status
{
  	
    NEW $namespace
	SET $namespace = "%SYS"

	SET tSC = $System.Status.OK()
	SET arrayEnsNamespace = []

    TRY {

		SET oRS = ##class(%SQL.Statement).%New()
        
        SET tSC = oRS.%PrepareClassQuery("Config.Namespaces", "List")
       
        QUIT:$System.Status.IsError(tSC)
        
        SET result = oRS.%Execute()
        
        IF (result.%SQLCODE '< 0) {
	        WHILE result.%Next() {
	        	SET json = {}
	        	
	        	;Ensemble Namespace Only
	        	CONTINUE:(##class(%Library.EnsembleMgr).IsEnsembleNamespace(result.%GetData(1)) = 0)
	        	
	      		DO json.%Set("id",result.%GetData(1))
				DO json.%Set("text",result.%GetData(1)) 
				DO arrayEnsNamespace.%Push(json)
            }
        } ELSE {
            THROW ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
    } CATCH (oException) {
        SET tSC = oException.AsStatus()
    }
    
    WRITE arrayEnsNamespace.%ToJSON() 
    
    QUIT tSC
}

ClassMethod Resend(pNamespace, pIdResend) As %Status
{
	
    NEW $namespace
	SET $namespace = pNamespace
	
	SET tSC = $$$OK
	
	SET lenIds = $length(pIdResend,",")
	
	FOR i=1:1:lenIds {
		SET idMensagem = $piece(pIdResend,",",i)
		SET tSC = ##class(Ens.MessageHeader).ResendDuplicatedMessage(idMensagem)
		QUIT:$$$ISERR(tSC)
	}

	QUIT tSC
}

}