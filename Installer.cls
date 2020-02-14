Include %occInclude

Class App.Installer
{

XData MyInstall [ XMLNamespace = INSTALLER ]
{
<Manifest>
  <Default Name="NAMESPACE" Value="IRISMONITOR"/>
  <Default Name="DBNAME" Value="IRISMONITOR"/>
  <Default Name="APPPATH" Dir="/opt/irisapp/" />
  <Default Name="SOURCESPATH" Dir="${APPPATH}src" />
  <Default Name="CSPURL" Value="/csp/irismonitor" /> 
  <Default Name="RESOURCE" Value="%DB_${DBNAME}" /> 

  <Resource Name="${RESOURCE}" Description="Resource for IRIS History Monitor" Permission="RW"/>
  <Resource Name="%DB_IRISSYS" Description="The System database" Permission="R"/>

  <Namespace Name="${NAMESPACE}" Code="${DBNAME}" Data="${DBNAME}" Create="yes" Ensemble="0">
    <Configuration>
      <Database Name="${DBNAME}" Dir="${APPPATH}${DBNAME}" Create="yes" Resource="${RESOURCE}"/>
    </Configuration>

    <CSPApplication Url="${CSPURL}" Directory="${APPPATH}csp/" AuthenticationMethods="32" IsNamespaceDefault="true" ServeFiles="1" Recurse="1" />

    <Import File="${SOURCESPATH}/cls" Recurse="1"/>
  </Namespace>

  <Invoke Class="App.Installer" Method="CompileCSP">
    <Arg Value="${CSPURL}"/>
    <Arg Value="${NAMESPACE}"/>
  </Invoke>

  <Invoke Class="App.Installer" Method="CustomApplicationMetrics" />
</Manifest>
}

ClassMethod setup(ByRef pVars, pLogLevel As %Integer = 3, pInstaller As %Installer.Installer, pLogger As %Installer.AbstractLogger) As %Status [ CodeMode = objectgenerator, Internal ]
{
  Quit ##class(%Installer.Manifest).%Generate(%compiledclass, %code, "MyInstall")
}

ClassMethod CompileCSP(pApp As %String, pNamespace As %String) As %Status
{
  New $Namespace
  Set $Namespace = pNamespace

  Set list(pApp_"/*.csp") = "" 
  Do $System.OBJ.CompileList(.list,"ck")

  Quit $$$OK
}

ClassMethod CustomApplicationMetrics() As %Status
{
  New $Namespace
  Set $Namespace = "%SYS"

  Set status = ##class(SYS.Monitor.SAM.Config).AddApplicationClass("diashenrique.historymonitor.util.customSensors","IRISMONITOR")
  
  Quit status
}

}
