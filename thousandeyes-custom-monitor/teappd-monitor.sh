#!/bin/bash
# Convention: testname = <application>-<tier>-<node>
# Example: adcapital-frontend-frontend1
# ./teappd-monitor.py "<test name>" <TE account email> <TE API token> <test name>
./teappd-monitor.py "Lab" $THOUSANDEYES_USER $THOUSANDEYES_API_TOKEN "TeaStore Order - PageLoad"
