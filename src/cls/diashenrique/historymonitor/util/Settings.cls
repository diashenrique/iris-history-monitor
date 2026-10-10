/// The instance-wide switch of the new interface (spec 002 FR-002, research R4).
/// Off until an administrator turns it on:
///   do ##class(diashenrique.historymonitor.util.Settings).SetInterfaceEnabled(1)
/// Any monitor viewer can read it through GET /settings. This is configuration written only by an
/// administrator, not per-request state (constitution IV).
Class diashenrique.historymonitor.util.Settings
{

/// The one node that holds the setting, in the namespace of the application.
ClassMethod Stored() As %String
{
	Quit $Get(^diashenrique.historymonitor.Settings("interfaceEnabled"))
}

ClassMethod InterfaceEnabled() As %Boolean
{
	Quit ''..Stored()
}

/// The access decision, kept pure so the refusal can be tested: only %Admin_Manage:USE may change it.
ClassMethod CanChange(hasAdmin As %Boolean) As %Boolean
{
	Quit ''$Get(hasAdmin)
}

/// Turns the new interface on (1) or off (0) for the whole instance.
ClassMethod SetInterfaceEnabled(flag As %Boolean) As %Status
{
	Quit ..Restore(''$Get(flag))
}

/// Writes a stored value as is ("" removes it, which means off). Used by SetInterfaceEnabled and by
/// the tests to put back what they found. Same check as SetInterfaceEnabled.
ClassMethod Restore(value As %String) As %Status
{
	If '..CanChange($SYSTEM.Security.Check("%Admin_Manage", "USE")) {
		Quit $$$ERROR($$$GeneralError, "Changing the History Monitor interface switch requires %Admin_Manage:USE")
	}
	If $Get(value) = "" {
		Kill ^diashenrique.historymonitor.Settings("interfaceEnabled")
	} Else {
		Set ^diashenrique.historymonitor.Settings("interfaceEnabled") = ''value
	}
	Quit $$$OK
}

}
