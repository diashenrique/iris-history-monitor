#!/bin/sh
# Prepares an IRIS container for the interface end-to-end tests (spec 002, task T023):
# IPM 0.10.9, the module loaded from the repository mounted at /home/irisowner/repo, 90 days of demo
# history, a monitor viewer and a user without the role, and the interface switched on.
# Usage: e2e-setup.sh <container> ; passwords come from HM_VIEWER_PASSWORD and HM_NOROLE_PASSWORD.
set -eu
C="$1"
: "${HM_VIEWER_PASSWORD:?}" "${HM_NOROLE_PASSWORD:?}"
run() { docker exec "$C" iris session IRIS -U "$1" "$2"; }

if ! run USER '##class(%Dictionary.CompiledClass).%ExistsId("%IPM.Main")' | grep -q 1; then
  curl -sSL -f -o /tmp/zpm.xml https://pm.community.intersystems.com/packages/zpm/0.10.9/installer
  docker cp /tmp/zpm.xml "$C":/tmp/zpm.xml
  run %SYS '##class(%SYSTEM.OBJ).Load("/tmp/zpm.xml","c")' >/dev/null
fi
run USER '##class(%IPM.Main).Shell("load /home/irisowner/repo")' > /tmp/ipm-load.txt 2>&1 || true
grep -q "Activate SUCCESS" /tmp/ipm-load.txt || { cat /tmp/ipm-load.txt; exit 1; }
run %SYS '##class(SYS.History.SysData).Demo(90)' >/dev/null
for u in e2eviewer:HistoryMonitorViewer:"$HM_VIEWER_PASSWORD" e2enorole::"$HM_NOROLE_PASSWORD"; do
  name=${u%%:*}; rest=${u#*:}; role=${rest%%:*}; pass=${rest#*:}
  run %SYS "##class(Security.Users).Delete(\"$name\")" >/dev/null 2>&1 || true
  run %SYS "##class(Security.Users).Create(\"$name\",\"$role\",\"$pass\")" >/dev/null
done
run USER '##class(diashenrique.historymonitor.util.Settings).SetInterfaceEnabled(1)' >/dev/null
echo "e2e setup done"
