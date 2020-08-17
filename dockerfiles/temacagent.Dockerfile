FROM appdynamics/machine-agent-analytics

# ENV MACHINE_AGENT_HOME defined by machine-agent-analytics
# Ref: https://github.com/Appdynamics/docker-machine-agent

RUN apt-get update -yqq  && \
    apt-get upgrade -yqq  &&  \
    apt-get install -yqq procps unzip python3 python3-pip && \
    apt-get -y clean
#RUN yum -y  install curl procps vim-enhanced net-tools iputils-ping iproute2

# Add ThousdanEye Monitoring extension to the Machine Agent monitors dir
ADD thousandeyes-custom-monitor ${MACHINE_AGENT_HOME}/monitors/ThousandEyes/
RUN chmod +x ${MACHINE_AGENT_HOME}/monitors/ThousandEyes/teappd-monitor.sh
COPY ctl.sh                     ${MACHINE_AGENT_HOME}/
COPY envvars.sh                 ${MACHINE_AGENT_HOME}/

ENTRYPOINT ${MACHINE_AGENT_HOME}/ctl.sh start-container

#CMD [ "sleep", "3600" ]
