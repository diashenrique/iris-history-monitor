/// REST dispatch class for the History Monitor API v1 (spec 001-api-v1).
/// Routes are added by tasks T008, T013, T017 and T020.
Class diashenrique.historymonitor.api.Dispatch Extends %CSP.REST
{

Parameter CONTENTTYPE = "application/json";

Parameter CHARSET = "utf-8";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
</Routes>
}

}
