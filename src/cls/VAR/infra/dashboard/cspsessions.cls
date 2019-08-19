Class VAR.infra.dashboard.cspsessions Extends %CSP.Page
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

/// do ##class(VAR.infra.dashboard.cspsessions).getCSPLiveHistory()
ClassMethod getCSPLiveHistory() As %Status
{
    SET (dtFrom,dtTo)=""

    SET dtFrom = $get(%request.Data("fiveMinFrom",1))
    SET dtTo   = $get(%request.Data("fiveMinTo",1))
    
    IF (dtTo = "") {
	    SET dtTo = +$horolog
    } ELSE {
	 	SET dtTo = $zdateh(dtTo,4)
    }
    
    IF (dtFrom = "") {
    	SET dtFrom = dtTo - 6
    } ELSE {
	    SET dtFrom = $zdateh(dtFrom,4)
    }
     
    NEW $namespace
	SET $namespace = "%SYS"

    SET tSC = $System.Status.OK()
    SET arrayLicenseLive = []

    TRY {
	    SET oRS = ##class(%SQL.Statement).%New()
        
        SET sql = "SELECT top 1000 DateTime, NVL(Sys_CSPSession,0) as CSPSession FROM SYS_History.SysData WHERE ZDATE BETWEEN "_dtFrom_" AND "_dtTo

        SET tSC = oRS.%Prepare(sql)
        
        QUIT:$System.Status.IsError(tSC)
        
        SET result = oRS.%Execute()
        
        IF (result.%SQLCODE '< 0) {
	        
            WHILE result.%Next() {
	            SET arrayDados = [] 
				SET arrayDados."0" = ..DateTimeToISO8601(result.DateTime)
				SET arrayDados."1" = result.CSPSession
				DO arrayLicenseLive.%Push(arrayDados)
            }
            
        } ELSE {
            THROW ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
    } CATCH (oException) {
        SET tSC = oException.AsStatus()
    }
    
    WRITE arrayLicenseLive.%ToJSON() 
    
    QUIT tSC
}

/// do ##class(VAR.infra.dashboard.cspsessions).getCSPSessionEveryFiveMinDataGrid()
ClassMethod getCSPSessionEveryFiveMinDataGrid() As %Status
{
    SET (dtFrom,dtTo)=""

    SET dtFrom = $get(%request.Data("fiveMinFrom",1))
    SET dtTo   = $get(%request.Data("fiveMinTo",1))
        
    IF (dtTo = "") {
	    SET dtTo = +$horolog
    } ELSE {
	 	SET dtTo = $zdateh(dtTo,4)
    }
    
    IF (dtFrom = "") {
    	SET dtFrom = dtTo - 6
    } ELSE {
	    SET dtFrom = $zdateh(dtFrom,4)
    }
    
    NEW $namespace
	SET $namespace = "%SYS"

    SET tSC = $System.Status.OK()
    SET arrayCSPFiveMin = []

    TRY {
	    SET oRS = ##class(%SQL.Statement).%New()
        
        SET sql = "SELECT top 1000 DateTime, NVL(Sys_CSPSession,0) as CSPSession FROM SYS_History.SysData WHERE ZDATE BETWEEN "_dtFrom_" AND "_dtTo

        SET tSC = oRS.%Prepare(sql)
        
        QUIT:$System.Status.IsError(tSC)
        
        SET result = oRS.%Execute()
        
        IF (result.%SQLCODE '< 0) {
	        
            WHILE result.%Next() {
	            SET json = {} 
	            SET dia  = $piece(result.DateTime," ",1)
	            SET hora = $piece(result.DateTime," ",2)
				DO json.%Set("date",$zdate($zdateh(dia,3),4))
				DO json.%Set("time",hora)
				DO json.%Set("cspSessions",$number(result.CSPSession))
				DO arrayCSPFiveMin.%Push(json)
            }
            
        } ELSE {
            THROW ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
    } CATCH (oException) {
        SET tSC = oException.AsStatus()
    }
    
    WRITE arrayCSPFiveMin.%ToJSON() 
    
    QUIT tSC
}

/// do ##class(VAR.infra.dashboard.cspsessions).getCSPHourlyHistory()
ClassMethod getCSPHourlyHistory() As %Status
{
	KILL ^IRISMonitor("CSP","Hourly")
	
	SET (dtFrom,dtTo)=""
    
    SET dtFrom = $get(%request.Data("hourFrom",1))
    SET dtTo   = $get(%request.Data("hourTo",1))
    
    IF (dtTo = "") {
	    SET dtTo = +$horolog
    } ELSE {
	 	SET dtTo = $zdateh(dtTo,4)
    }
    
    IF (dtFrom = "") {
    	SET dtFrom = dtTo - 6
    } ELSE {
	    SET dtFrom = $zdateh(dtFrom,4)
    }
	
	NEW $namespace
	SET $namespace = "%SYS"
	
    SET tSC = $System.Status.OK()

    TRY {
	    SET oRS = ##class(%SQL.Statement).%New()
        
        SET sql = "SELECT Hourly, element_key as Metrica, NVL(Sys_CSPSession,0) as CSPSession FROM SYS_History.Hourly_Sys WHERE Hourly->ZDATE BETWEEN "_dtFrom_" AND "_dtTo

        SET tSC = oRS.%Prepare(sql)
        
        QUIT:$System.Status.IsError(tSC)
        
        SET result = oRS.%Execute()
        
        IF (result.%SQLCODE '< 0) {
	        
            WHILE result.%Next() {
	            SET data = $piece(result.Hourly,"||",1)
	            SET hora = $piece(result.Hourly,"||",2)
	            SET metrica  = result.Metrica
	            SET sessions = result.CSPSession
	            
	            CONTINUE:(metrica="StDev")
	            
	            SET datetimeUTC = $SYSTEM.SQL.DATEDIFF("s","1970-01-01 00:00:00",$zdatetime(data_","_hora,3)) * 1000
	            
	            SET ^["IRISMONITOR"]IRISMonitor("CSP","Hourly",metrica,data,hora) = datetimeUTC_"^"_sessions
            }
            
        } ELSE {
            THROW ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
        
        SET $namespace = "IRISMONITOR"
        SET arrHourly = []

        // Métrica (Max, Avg, StDev)
		SET idMetrica = ""
		FOR {
			SET idMetrica=$order(^IRISMonitor("CSP","Hourly",idMetrica))
			QUIT:idMetrica=""
			
			SET arrMetrica = [] 
			
			// Data  
			SET dtData = ""
			FOR {
				SET dtData=$order(^IRISMonitor("CSP","Hourly",idMetrica,dtData))
				QUIT:dtData=""

				// Horario 
				SET inthora = ""
				FOR {
					SET inthora=$order(^IRISMonitor("CSP","Hourly",idMetrica,dtData,inthora))
					QUIT:inthora=""
					
					SET arrDados = []
					
					SET obj = $get(^IRISMonitor("CSP","Hourly",idMetrica,dtData,inthora))
					
					SET arrDados."0" = $number($piece(obj,"^",1))		;DateTime UTC Format 
					SET arrDados."1" = $normalize($piece(obj,"^",2),2)	;CSP Sessions
					
					DO arrMetrica.%Push(arrDados)
				}
				
			}
			
			SET json = {}, jsonMarker ={}, jsonfillColor = {}, jsonlinearGradient = {}, arrStops = [], arrAllStops = []

			SET colorCode = $select(idMetrica="Max":"#00bd56",idMetrica="Avg":"#85ef47",1:"#f9fd50")
			
			DO json.%Set("name",idMetrica)
			DO json.%Set("data",arrMetrica)
			DO json.%Set("color",colorCode)
			DO json.%Set("lineColor",colorCode)
			
			DO jsonMarker.%Set("enabled",0)
			DO jsonMarker.%Set("symbol","circle")
			DO jsonMarker.%Set("radius",2)
			DO jsonMarker.%Set("lineWidth",1)
			DO jsonMarker.%Set("lineColor",colorCode)
			DO jsonMarker.%Set("fillColor","#ffffff") 
			DO json.%Set("marker",jsonMarker)
			
			DO jsonlinearGradient.%Set("x1",0)
			DO jsonlinearGradient.%Set("x2",0)
			DO jsonlinearGradient.%Set("y1",0)
			DO jsonlinearGradient.%Set("y2",1)
			
			SET arrStops=[].%Push(0).%Push(colorCode)
            DO arrAllStops.%Push(arrStops)
            SET arrStops=[].%Push(1).%Push("#ffffff")
            DO arrAllStops.%Push(arrStops)
			
			DO jsonfillColor.%Set("linearGradient",jsonlinearGradient)
			DO jsonfillColor.%Set("stops",arrAllStops)
			DO json.%Set("fillColor",jsonfillColor)
			
			DO arrHourly.%Push(json)
		}
        
    } CATCH (oException) {
        SET tSC = oException.AsStatus()
    }
    
    WRITE arrHourly.%ToJSON() 
    
    QUIT tSC
}

/// do ##class(VAR.infra.dashboard.cspsessions).getCSPHourlyDataGrid()
ClassMethod getCSPHourlyDataGrid() As %Status
{
	KILL ^IRISMonitor("CSP","HourlyDataGrid")
	
	SET (dtFrom,dtTo)=""
    
    SET dtFrom = $get(%request.Data("hourFrom",1))
    SET dtTo   = $get(%request.Data("hourTo",1))
    
    IF (dtTo = "") {
	    SET dtTo = +$horolog
    } ELSE {
	 	SET dtTo = $zdateh(dtTo,4)
    }
    
    IF (dtFrom = "") {
    	SET dtFrom = dtTo - 6
    } ELSE {
	    SET dtFrom = $zdateh(dtFrom,4)
    }
	
	NEW $namespace
	SET $namespace = "%SYS"
	
    SET tSC = $System.Status.OK()

    TRY {
	    SET oRS = ##class(%SQL.Statement).%New()
        
        SET sql = "SELECT Hourly, element_key as Metrica, NVL(Sys_CSPSession,0) as CSPSession FROM SYS_History.Hourly_Sys WHERE Hourly->ZDATE BETWEEN "_dtFrom_" AND "_dtTo

        SET tSC = oRS.%Prepare(sql)
        
        QUIT:$System.Status.IsError(tSC)
        
        SET result = oRS.%Execute()
        
        IF (result.%SQLCODE '< 0) {
	        
            WHILE result.%Next() {
	            SET data = $piece(result.Hourly,"||",1)
	            SET hora = $piece(result.Hourly,"||",2)
	            SET metrica  = result.Metrica
	            SET sessions = result.CSPSession
	            
	            CONTINUE:(metrica="StDev")
	            
	            SET obj = $get(^["IRISMONITOR"]IRISMonitor("CSP","HourlyDataGrid",data,hora))
	            SET $piece(obj,"^",1) = $zdate(data,4)
	            SET $piece(obj,"^",2) = $ztime(hora,2)
	            IF (metrica="Avg") {
		            SET $piece(obj,"^",3) = sessions
	            } ELSE {
		            SET $piece(obj,"^",4) = sessions
	            }
	            	            
	            SET ^["IRISMONITOR"]IRISMonitor("CSP","HourlyDataGrid",data,hora) = obj
            }
            
        } ELSE {
            THROW ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
        
        SET $namespace = "IRISMONITOR"
        
        SET arrHourlyDataGrid = []

		SET dia = ""
		FOR {
			SET dia=$order(^IRISMonitor("CSP","HourlyDataGrid",dia))
			QUIT:dia=""
			
			SET horario = ""
			FOR {
				SET horario=$order(^IRISMonitor("CSP","HourlyDataGrid",dia,horario))
				QUIT:horario=""
				
				SET oHourly = $get(^IRISMonitor("CSP","HourlyDataGrid",dia,horario))

				SET json = {} 
				DO json.%Set("date",$piece(oHourly,"^",1))
				DO json.%Set("time",$piece(oHourly,"^",2))
				DO json.%Set("avg",$normalize($piece(oHourly,"^",3),2))
				DO json.%Set("max",$normalize($piece(oHourly,"^",4),2))
				DO arrHourlyDataGrid.%Push(json)	
			}
		}
        
    } CATCH (oException) {
        SET tSC = oException.AsStatus()
    }
    
    WRITE arrHourlyDataGrid.%ToJSON() 
    
    QUIT tSC
}

/// do ##class(VAR.infra.dashboard.cspsessions).getCSPDailyHistory()
ClassMethod getCSPDailyHistory() As %Status
{
	KILL ^IRISMonitor("CSP","Daily")
	
	SET (dtFrom,dtTo)=""
    
    SET dtFrom = $get(%request.Data("dayFrom",1))
    SET dtTo   = $get(%request.Data("dayTo",1))
    
    IF (dtTo = "") {
	    SET dtTo = +$horolog
    } ELSE {
	 	SET dtTo = $zdateh(dtTo,4)
    }
    
    IF (dtFrom = "") {
    	SET dtFrom = dtTo - 6
    } ELSE {
	    SET dtFrom = $zdateh(dtFrom,4)
    }

	NEW $namespace
	SET $namespace = "%SYS"
	
    SET tSC = $System.Status.OK()

    TRY {
	    SET oRS = ##class(%SQL.Statement).%New()
        
        SET sql = "SELECT Daily, element_key as Metrica, NVL(Sys_CSPSession,0) as CSPSession FROM SYS_History.Daily_Sys WHERE Daily->ZDATE BETWEEN "_dtFrom_" AND "_dtTo

        SET tSC = oRS.%Prepare(sql)
        
        QUIT:$System.Status.IsError(tSC)
        
        SET result = oRS.%Execute()
        
        IF (result.%SQLCODE '< 0) {
	        
            WHILE result.%Next() {
	            SET data = $piece(result.Daily,"||",1)
	            SET hora = $piece(result.Daily,"||",2)
	            SET metrica  = result.Metrica
	            SET sessions = result.CSPSession
	            
	            CONTINUE:(metrica="StDev")
	            
	            SET datetimeUTC = $SYSTEM.SQL.DATEDIFF("s","1970-01-01 00:00:00",$zdatetime(data_","_hora,3)) * 1000
	            
	            SET ^["IRISMONITOR"]IRISMonitor("CSP","Daily",metrica,data,hora) = datetimeUTC_"^"_sessions
            }
            
        } ELSE {
            THROW ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
        
        SET $namespace = "IRISMONITOR"
        SET arrDaily = []

        // Métrica (Max, Avg, StDev)
		SET idMetrica = ""
		FOR {
			SET idMetrica=$order(^IRISMonitor("CSP","Daily",idMetrica))
			QUIT:idMetrica=""
			
			SET arrMetrica = [] 
			
			// Data  
			SET dtData = ""
			FOR {
				SET dtData=$order(^IRISMonitor("CSP","Daily",idMetrica,dtData))
				QUIT:dtData=""

				// Horario 
				SET inthora = ""
				FOR {
					SET inthora=$order(^IRISMonitor("CSP","Daily",idMetrica,dtData,inthora))
					QUIT:inthora=""
					
					SET arrDados = []
					
					SET obj = $get(^IRISMonitor("CSP","Daily",idMetrica,dtData,inthora))
					
					SET arrDados."0" = $number($piece(obj,"^",1))		;DateTime UTC Format 
					SET arrDados."1" = $normalize($piece(obj,"^",2),2)	;CSP Sessions
					
					DO arrMetrica.%Push(arrDados)
				}
				
			}
			
			SET json = {}, jsonMarker ={}, jsonfillColor = {}, jsonlinearGradient = {}, arrStops = [], arrAllStops = []

			SET colorCode = $select(idMetrica="Max":"#005542",idMetrica="Avg":"#cdeeaa",1:"#dfdfdf")
			
			DO json.%Set("name",idMetrica)
			DO json.%Set("data",arrMetrica)
			DO json.%Set("color",colorCode)
			DO json.%Set("lineColor",colorCode)
			
			DO jsonMarker.%Set("enabled",0)
			DO jsonMarker.%Set("symbol","circle")
			DO jsonMarker.%Set("radius",2)
			DO jsonMarker.%Set("lineWidth",1)
			DO jsonMarker.%Set("lineColor",colorCode)
			DO jsonMarker.%Set("fillColor","#ffffff") 
			DO json.%Set("marker",jsonMarker)
			
			DO jsonlinearGradient.%Set("x1",0)
			DO jsonlinearGradient.%Set("x2",0)
			DO jsonlinearGradient.%Set("y1",0)
			DO jsonlinearGradient.%Set("y2",1)
			
			SET arrStops=[].%Push(0).%Push(colorCode)
            DO arrAllStops.%Push(arrStops)
            SET arrStops=[].%Push(1).%Push("#ffffff")
            DO arrAllStops.%Push(arrStops)
			
			DO jsonfillColor.%Set("linearGradient",jsonlinearGradient)
			DO jsonfillColor.%Set("stops",arrAllStops)
			DO json.%Set("fillColor",jsonfillColor)
			
			DO arrDaily.%Push(json)
		}
        
    } CATCH (oException) {
        SET tSC = oException.AsStatus()
    }
    
    WRITE arrDaily.%ToJSON() 
    
    QUIT tSC
}

/// do ##class(VAR.infra.dashboard.cspsessions).getCSPDailyDataGrid()
ClassMethod getCSPDailyDataGrid() As %Status
{
	KILL ^IRISMonitor("CSP","DailyDataGrid")	
	
	SET (dtFrom,dtTo)=""
    
    SET dtFrom = $get(%request.Data("dayFrom",1))
    SET dtTo   = $get(%request.Data("dayTo",1))
    
    IF (dtTo = "") {
	    SET dtTo = +$horolog
    } ELSE {
	 	SET dtTo = $zdateh(dtTo,4)
    }
    
    IF (dtFrom = "") {
    	SET dtFrom = dtTo - 6
    } ELSE {
	    SET dtFrom = $zdateh(dtFrom,4)
    }

	NEW $namespace
	SET $namespace = "%SYS"
	
    SET tSC = $System.Status.OK()

    TRY {
	    SET oRS = ##class(%SQL.Statement).%New()
        
        SET sql = "SELECT Daily, element_key as Metrica, NVL(Sys_CSPSession,0) as CSPSession FROM SYS_History.Daily_Sys WHERE Daily->ZDATE BETWEEN "_dtFrom_" AND "_dtTo

        SET tSC = oRS.%Prepare(sql)
        
        QUIT:$System.Status.IsError(tSC)
        
        SET result = oRS.%Execute()
        
        IF (result.%SQLCODE '< 0) {
	        
            WHILE result.%Next() {
	            SET data = $piece(result.Daily,"||",1)
	            SET hora = $piece(result.Daily,"||",2)
	            SET metrica  = result.Metrica
	            SET sessions = result.CSPSession
	            
	            CONTINUE:(metrica="StDev")
	            
	            SET obj = $get(^["IRISMONITOR"]IRISMonitor("CSP","DailyDataGrid",data,hora))
	            SET $piece(obj,"^",1) = $zdate(data,4)
	            SET $piece(obj,"^",2) = $ztime(hora,2)
	            IF (metrica="Avg") {
		            SET $piece(obj,"^",3) = sessions
	            } ELSE {
		            SET $piece(obj,"^",4) = sessions
	            }
	            	            
	            SET ^["IRISMONITOR"]IRISMonitor("CSP","DailyDataGrid",data,hora) = obj
            }
            
        } ELSE {
            THROW ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
        }
        
        SET $namespace = "IRISMONITOR"
        
        SET arrDailyDataGrid = []

		SET dia = ""
		FOR {
			SET dia=$order(^IRISMonitor("CSP","DailyDataGrid",dia))
			QUIT:dia=""
			
			SET horario = ""
			FOR {
				SET horario=$order(^IRISMonitor("CSP","DailyDataGrid",dia,horario))
				QUIT:horario=""
				
				SET oDaily = $get(^IRISMonitor("CSP","DailyDataGrid",dia,horario))

				SET json = {} 
				DO json.%Set("date",$piece(oDaily,"^",1))
				DO json.%Set("time",$piece(oDaily,"^",2))
				DO json.%Set("avg",$normalize($piece(oDaily,"^",3),2))
				DO json.%Set("max",$normalize($piece(oDaily,"^",4),2))
				DO arrDailyDataGrid.%Push(json)	
			}
		}
		
    } CATCH (oException) {
        SET tSC = oException.AsStatus()
    }
    
    WRITE arrDailyDataGrid.%ToJSON() 
    
    QUIT tSC
}

/// do ##class(VAR.infra.dashboard.license).DateTimeToISO8601("2019-03-22 08:58:06")
ClassMethod DateTimeToISO8601(pDateTime As %DateTime) As %String
{
	QUIT:(pDateTime="") ""
	
	SET ret = $case(pDateTime,"":"",:$replace(pDateTime," ","T")_"Z")
	
	QUIT ret
}

}
