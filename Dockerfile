ARG IMAGE=store/intersystems/iris-community:2019.3.0.309.0
ARG IMAGE=store/intersystems/iris-community:2019.4.0.379.0
ARG IMAGE=store/intersystems/iris-community:2019.4.0.383.0
ARG IMAGE=intersystemsdc/iris-community:2020.2.0.196.0-zpm
FROM $IMAGE

USER root

WORKDIR /opt/irisapp
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisapp
COPY irissession.sh /
RUN chmod +x /irissession.sh 

USER irisowner

COPY  Installer.cls .
COPY  src src

# running IRIS and open IRIS termninal in USER namespace
SHELL ["/irissession.sh"]
# below is objectscript executed in terminal
# each row is what you type in terminal and Enter
# zpm "install webterminal" 
RUN \
    do $SYSTEM.OBJ.Load("Installer.cls", "ck") \
    set sc = ##class(App.Installer).setup() \
    zn "IRISMONITOR" 

# bringing the standard shell back
SHELL ["/bin/bash", "-c"]
CMD [ "-l", "/usr/irissys/mgr/messages.log" ]