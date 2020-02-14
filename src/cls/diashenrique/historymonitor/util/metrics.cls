Class diashenrique.historymonitor.util.metrics Extends %CSP.Page
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

ClassMethod readMetrics() As %Status
{
    Set urlhostname = $Get(%request.Data("urlhostname",1))
    Set urlport = $Get(%request.Data("urlport",1))

    Set httprequest = ##class(%Net.HttpRequest).%New()
    Set httprequest.Server = urlhostname
    Set httprequest.Port = urlport
    Do httprequest.Get("/api/monitor/metrics")

    Set arrayMetrics = []
    Set jsonMetrics = { }

    If (httprequest.HttpResponse.StatusCode = 200) {
        If $IsObject(httprequest.HttpResponse.Data) {
            While 'httprequest.HttpResponse.Data.AtEnd {

                Set keyName = ""
                Set str = httprequest.HttpResponse.Data.ReadLine() 

                If ($Find(str,"iris_csp_sessions") > 0) {
                    Set keyName = "CSPSessions"
                }
                ElseIf ($Find(str,"iris_cache_efficiency") > 0) {
                    Set keyName = "CacheEfficiency"
                }
                ElseIf ($Find(str,"iris_process_count") > 0) {
                    Set keyName = "Processes"
                }
                ElseIf ($Find(str,"iris_system_alerts") > 0) {
                    Set keyName = "SeriousAlerts"
                }
                ElseIf ($Find(str,"irismonitor_applicationerrors") > 0) {
                    Set keyName = "ApplicationErrors"
                }
                ElseIf ($Find(str,"irismonitor_ecpappserver") > 0) {
                    Set keyName = "ECPAppServer"
                }
                ElseIf ($Find(str,"irismonitor_ecpdataserver") > 0) {
                    Set keyName = "ECPDataServer"
                }
                ElseIf ($Find(str,"irismonitor_journalspace") > 0) {
                    Set keyName = "JournalSpace"
                }
                ElseIf ($Find(str,"irismonitor_journalstatus") > 0) {
                    Set keyName = "JournalStatus"
                }
                ElseIf ($Find(str,"irismonitor_lastbackup") > 0) {
                    Set keyName = "LastBackup"
                }
                ElseIf ($Find(str,"irismonitor_locktable") > 0) {
                    Set keyName = "LockTable"
                }
                ElseIf ($Find(str,"irismonitor_systemuptime") > 0) {
                    Set keyName = "SystemUpTime"
                }
                ElseIf ($Find(str,"irismonitor_writedaemon") > 0) {
                    Set keyName = "WriteDaemon"
                }
                ElseIf ($Find(str,"irismonitor_licensecurrent ") > 0) {
                    Set keyName = "LicenseCurrent"
                }
                ElseIf ($Find(str,"irismonitor_licensecurrentpct ") > 0) {
                    Set keyName = "LicenseCurrentPct"
                }
                ElseIf ($Find(str,"irismonitor_licensehigh ") > 0) {
                    Set keyName = "LicenseHigh"
                }
                ElseIf ($Find(str,"irismonitor_licensehighpct ") > 0) {
                    Set keyName = "LicenseHighPct"
                }
                ElseIf ($Find(str,"irismonitor_licenselimit") > 0) {
                    Set keyName = "LicenseLimit"
                }

                If (keyName '="") {
                    Do jsonMetrics.%Set(keyName, $Extract(str,$Find(str," "),*))
                }
            }
        }    
    }

    Write $Replace($Replace(jsonMetrics.%ToJSON(),"""'",""),"'""","")

    Quit $$$OK
}

}
