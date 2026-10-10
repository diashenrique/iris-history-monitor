# IRIS History Monitor on IRIS Community, installed with IPM like any user would install it.
# The version is pinned to the one the CI and the end-to-end tests run against.
ARG IMAGE=intersystemsdc/iris-community:2026.1
FROM $IMAGE

ARG IPM_VERSION=0.10.9

USER root
WORKDIR /opt/irisapp
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisapp
COPY --chmod=755 irissession.sh /
# IPM installer, pinned (the image has no curl).
ADD --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} \
    https://pm.community.intersystems.com/packages/zpm/${IPM_VERSION}/installer /tmp/zpm.xml

USER ${ISC_PACKAGE_MGRUSER}
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} module.xml Installer.cls ./
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} src src

# Runs IRIS during the build and types the lines below into a terminal in %SYS (see irissession.sh):
# install IPM, create the IRISMONITOR namespace (the module's own namespace), and load the module with
# IPM. The build fails if the API class is not there (irissession.sh stops on a false sc).
SHELL ["/irissession.sh"]
RUN \
    do $SYSTEM.OBJ.Load("/tmp/zpm.xml", "ck") \
    do $SYSTEM.OBJ.Load("/opt/irisapp/Installer.cls", "ck") \
    set sc = ##class(App.Installer).setup() \
    zn "IRISMONITOR" \
    do ##class(%IPM.Main).Shell("load /opt/irisapp") \
    set sc = ##class(%Dictionary.CompiledClass).%ExistsId("diashenrique.historymonitor.api.Dispatch")

SHELL ["/bin/bash", "-c"]
# The image's own entrypoint runs an after-start script that fails on 2026.1 and stops IRIS; start IRIS
# directly instead (the CI does the same).
ENTRYPOINT ["/tini", "--", "/iris-main"]
CMD ["-l", "/usr/irissys/mgr/messages.log"]
