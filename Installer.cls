Include %occInclude

/// Creates the IRISMONITOR namespace and database for the Docker image (Dockerfile). The module itself is
/// installed by IPM afterwards (module.xml): web applications, security role, favourite and pages.
/// The namespace keeps the module apart from USER; upgrades and uninstalls never delete it (spec 003 FR-006).
Class App.Installer
{

XData MyInstall [ XMLNamespace = INSTALLER ]
{
<Manifest>
  <Default Name="NAMESPACE" Value="IRISMONITOR"/>
  <Default Name="DBNAME" Value="IRISMONITOR"/>
  <Default Name="APPPATH" Dir="/opt/irisapp/" />
  <Default Name="RESOURCE" Value="%DB_${DBNAME}" />

  <Resource Name="${RESOURCE}" Description="Resource for IRIS History Monitor" Permission=""/>

  <Namespace Name="${NAMESPACE}" Code="${DBNAME}" Data="${DBNAME}" Create="yes" Ensemble="0">
    <Configuration>
      <Database Name="${DBNAME}" Dir="${APPPATH}${DBNAME}" Create="yes" Resource="${RESOURCE}"/>
    </Configuration>
  </Namespace>
</Manifest>
}

ClassMethod setup(ByRef pVars, pLogLevel As %Integer = 3, pInstaller As %Installer.Installer, pLogger As %Installer.AbstractLogger) As %Status [ CodeMode = objectgenerator, Internal ]
{
  Quit ##class(%Installer.Manifest).%Generate(%compiledclass, %code, "MyInstall")
}

}
