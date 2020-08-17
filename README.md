# AppD-ThousandEyes-test1
Provides docker and K8s containers with AppDynamics Machine Agent and ThousandEyes monitoring extension deployed

Configure the environment using the environment variables in the file:

```envvars.sh```

Download, unzip and configure the ThousandEyes monitoring extension into the dir:

```thousandeyes-custom-monitor```

Build the container using the command:

```ctl.sh build```

Run the container using the command:

```ctl.sh run```

Bash into the container to check everything is working:

```ctl.sh run```

Check the logs in the dir:

```/opt/appdynamics/logs```


