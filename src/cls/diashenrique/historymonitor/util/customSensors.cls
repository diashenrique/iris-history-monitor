/// Example of a custom class for the /metric API
Class diashenrique.historymonitor.util.customSensors Extends %SYS.Monitor.SAM.Abstract
{

Parameter PRODUCT = "irismonitor";

/// Collect metrics from 
Method GetSensors() As %Status
{
    Do ..getDashboardWS(.dashboard)

    Do ..SetSensor("systemuptime",dashboard.SystemUpTime)
    Do ..SetSensor("lastbackup",dashboard.LastBackup)
    Do ..SetSensor("locktable",dashboard.LockTable)
    Do ..SetSensor("journalspace",dashboard.JournalSpace)
    Do ..SetSensor("journalstatus",dashboard.JournalStatus)
    Do ..SetSensor("ecpappserver",dashboard.ECPAppServer)
    Do ..SetSensor("ecpdataserver",dashboard.ECPDataServer)
    Do ..SetSensor("writedaemon",dashboard.WriteDaemon)
    Do ..SetSensor("licensecurrent",dashboard.LicenseCurrent)
    Do ..SetSensor("licensecurrentpct",dashboard.LicenseCurrentPct)
    Do ..SetSensor("licensehigh",dashboard.LicenseHigh)
    Do ..SetSensor("licensehighpct",dashboard.LicenseHighPct)
    Do ..SetSensor("licenselimit",dashboard.LicenseLimit)
    Do ..SetSensor("applicationerrors",dashboard.ApplicationErrors)

    Return $$$OK
}

ClassMethod getDashboardWS(Output dashboard)
{
    New $Namespace
    Set $Namespace = "%SYS"

    Do ##class(Config.Startup).Get(.Prop)
    Set webPort = Prop("WebServerPort")

    Set client = ##class(SYS.WSMon.Client).%New()
    Set client.Location = "http://localhost:"_webPort_"/csp/sys/SYS.WSMon.Service.cls"
    Set dashboard = client.GetDashboard()

    Quit $$$OK
}

ClassMethod CustomApplicationMetrics() As %Status
{
    Set oldNamespace = $Namespace
    New $Namespace
    Set $Namespace = "%SYS"

    Set status = ##class(SYS.Monitor.SAM.Config).AddApplicationClass("diashenrique.historymonitor.util.customSensors",oldNamespace)

    Quit status
}

}
