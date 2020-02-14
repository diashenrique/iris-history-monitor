# IRIS History Monitor

This personal project has the intention to show in a visual way the information generate by the System Monitor _**^%SYSMONMGR**_ and a different approach for the System Dashboard and System Processes.

## How to Run

To start coding with this repo, you do the following:

1. Clone/git pull the repo into any local directory

```
$ git clone https://github.com/diashenrique/iris-history-monitor.git
```

2. Open the terminal in this directory and run:

```
$ docker-compose build
```

3. Run the IRIS container with your project:

```
$ docker-compose up -d
```

## How to test

Open the browser and go

Ex.: <http://localhost:52773/csp/irismonitor/dashboard.csp>

The username \_SYSTEM can run the dashboard and the other features.

## System Dashboard

![System Dashboard](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master//images/SystemDashboard.png)

System Dashboard shows the following items:

- Licensing
- System Time
- Application Errors
- Cache Processes
- CSP Sessions
- Lock Table
- Journal Space
- Journal Status
- ECP AppServer
- ECP DataServer
- Write Daemon
- Cache Efficiency
- Serious Alerts

The line charts widgets plot a point every 5 seconds
![Widget_SystemDashboard](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/widget_dashboard.gif)

## System Menu

![Menu](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/menu.gif)

## System Processes

![System Processes](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/SystemProcesses.png)

## Processes Filters

![System Processes filters](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/SystemProcesses_filter.gif)

Use different filters to achieve the result that you need. You can also use Multiple Sorts, pressing `Shift` + `clicking on the column header.` and even export the data grid to _**Excel**_!

![System Processes Excel](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/SystemProcesses_output.png)

## History Monitor

The History Monitor for CSP Sessions and Licensing shows the information between three sections:

- Every 5 Minutes
- Daily
- Hourly

Database Growth _only_ shows Daily information.

The history pages share the features below:

### Date Range Picker

![Date Range Picker](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/daterangepicker.png)

The default value is "Last 7 Days."

### Chart / Data Table

On the top right of every each section, there are two buttons (Chart/Data Table)

![Chart_DataTable](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/chart.png)

The Data Table shows the information that creates the chart, and you can also download in excel format.

![Data Table](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/chart_datagrid.png)

![Data Table Excel](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/chart_datagrid_output.png)

The excel shows the same format, content, and group defined in the CSP.

### Zooming

All charts have the Zoom option to visualize the information with more details.

![Chart_Zooming](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/demo_CSP_Sessions.gif)

### Average and Maximum

For the Sections Hourly and Daily, the charts show Average and Maximum values.

#### AVG

![Avg](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/History_Hourly.png)

#### Max

![Max](https://raw.githubusercontent.com/diashenrique/iris-history-monitor/master/images/History_Daily.png)
