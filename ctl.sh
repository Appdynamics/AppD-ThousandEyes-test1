#!/bin/bash
#
# Docker and Kuberntes helper script
#
# Maintainer: Davdi Ryder
#

CMD=${1:-"help"}
CMD_ARGS_LEN=${#}

echo $CMD $CMD_ARGS_LEN


# envvars
if [ -f envvars.sh ]; then
  . envvars.sh
else
  echo "Warning: envvars.sh not found"
fi

# if [ -f docker-ctl.sh ]; then
#   . docker-ctl.sh pass
# else
#   echo "Warning: docker-ctl.sh not found"
# fi

KUBECTL_CMD="microk8s.kubectl"


# Check docker: Linux or Ubuntu snap
DOCKER_CMD=`which docker`
DOCKER_CMD=${DOCKER_CMD:-"/snap/bin/microk8s.docker"}
echo "Using: "$DOCKER_CMD
if [ -d $DOCKER_CMD ]; then
    echo "Docker is missing: "$DOCKER_CMD
    exit 1
fi

_buildContainer() {
  DOCKERFILE="./$DOCKERFILES_DIR/$DOCKER_TAG_NAME.Dockerfile"
  echo "Building $DOCKERFILE Tag: $DOCKER_TAG_NAME"
  $DOCKER_CMD build \
    -t $DOCKER_TAG_NAME \
    --file $DOCKERFILE .
}

_createContainer() {
  echo "1"
}

_modify_Properties_file() {
  echo "Updating properties $1 to $2 in $3"
  V1=$(printf '%s\n' "$1"      | sed 's/[[\.*^$/]/\\&/g'   )
  NEW_VAL=$(printf '%s\n' "$2" | sed 's/[[\.*^$/]/\\&/g'   )
  MFILE=$3
  sed -i".backup"  "s/.*$V1.*/$V1=$NEW_VAL/" "$MFILE"
}

_dockerRun() {
  # Adds ports
  # Adds RW volume on host
  DOCKER_EXTRA_ARGS="$1"
  DOCKER_CONTAINER_ID=${2:-"0"}
  echo "Docker running $DOCKER_TAG_NAME ARGS[$DOCKER_EXTRA_ARGS]"
  $DOCKER_CMD run --rm --detach  \
            --name "$DOCKER_TAG_NAME$DOCKER_CONTAINER_ID" \
            --hostname "$DOCKER_TAG_NAME$DOCKER_CONTAINER_ID" \
            $DOCKER_EXTRA_ARGS \
            -it                \
            $DOCKER_TAG_NAME

  # --volume /tmp/dock-$DOCKER_TAG_NAME:/$DOCKER_TAG_NAME:rw \
}

_holdContainerOpen() {
  count=999999
  interval=60
  for i in $(seq $count )
  do
    echo "$i `date`" >> /tmp/container.log
    sleep $interval;
  done;
}




_createLocalContainerRepository() {
  IMAGE_NAME="registry"
  IMAGE_TAG="2.7.1"
  CONTANER_NAME="dock-registry"
  REGISTRY_DIR=$HOME"/Docker-Registry-Data"
  LOCAL_PORT="5555"
  if [ ! -d "$REGISTRY_DIR" ]; then
    echo "Creating local docker registry: $REGISTRY_DIR"
    mkdir -p $REGISTRY_DIR
  fi

  docker run -d \
    -p $LOCAL_PORT:5000 \
    --restart=always \
    --name $CONTANER_NAME \
    -v $REGISTRY_DIR:/var/lib/registry \
    $IMAGE_NAME:$IMAGE_TAG
}

ALL_BUILD_LIST=("temacagent")
ALL_RUN_LIST=("temacagent")

case "$CMD" in
  test)
    echo "Test"
    ;;
  start-container)
    . envvars.sh
    # Perform any configuration items _holdContainerOpen

    ${MACHINE_AGENT_HOME}/startup.sh
    sleep 9999
    ;;
  docker-create-repository)
    _createLocalContainerRepository
    ;;
  build) # Expects Argument APP_ID
    DOCKER_TAG_NAME=${2:-"$DOCKER_TAG_NAME"}

    _buildContainer $DOCKER_TAG_NAME
    ;;
  bash)
    DOCKER_TAG_NAME=${2:-"$DOCKER_TAG_NAME"}
    ./docker-ctl.sh bash $DOCKER_TAG_NAME
    ;;
  stop)
    DOCKER_TAG_NAME=${2:-"$DOCKER_TAG_NAME"}
    ./docker-ctl.sh stop $DOCKER_TAG_NAME
    ;;
  run)
    DOCKER_TAG_NAME=${2:-"$DOCKER_TAG_NAME"}
    ID=${3:-"0"}
    EXTRA_ARGS=""
    _dockerRun "$EXTRA_ARGS" $ID $DOCKER_TAG_NAME
  ;;
  push)
    DOCKER_TAG_NAME=${2:-"$DOCKER_TAG_NAME"}
    ./docker-ctl.sh push $DOCKER_TAG_NAME
    ;;
  ubuntu-update)
    sudo apt-get update
    DEBIAN_FRONTEND=noninteractive sudo apt-get -yqq upgrade
    DEBIAN_FRONTEND=noninteractive sudo apt-get -yqq install zip jq
    ;;
  configure)
    # All downloads go into downloads dir.
    mkdir -p downloads
    ;;
  build-all)
    for DOCKER_TAG_NAME in "${ALL_BUILD_LIST[@]}"; do
      _buildContainer $DOCKER_TAG_NAME
    done
    #docker system prune --all --force
    docker images
    ;;
  push-all)
    for TDIR in "${ALL_BUILD_LIST[@]}"; do
      _pushContainer $TDIR
    done
    #docker system prune --all --force
    docker images
    ;;
  create-all)
    for TDIR in "${ALL_RUN_LIST[@]}"; do
      echo "Creating $TDIR"
      $KUBECTL_CMD create -f $TDIR/main.yaml
    done
    ;;
  apply-all)
    for TDIR in "${ALL_RUN_LIST[@]}"; do
      echo "Applying $TDIR"
      $KUBECTL_CMD apply -f $TDIR/main.yaml
    done
    ;;
  delete-all)
    for TDIR in "${ALL_RUN_LIST[@]}"; do
      echo "Deleting $TDIR"
      $KUBECTL_CMD delete --filename $TDIR/main.yaml
    done
    ;;
  replace)
    BUILD_DIR=$2
    $KUBECTL_CMD replace --force --filename $BUILD_DIR/main.yaml
    ;;
  replace-all)
    for TDIR in "${ALL_RUN_LIST[@]}"; do
      echo "Replacing $TDIR"
      $KUBECTL_CMD replace --force --filename $TDIR/main.yaml
    done
    ;;
  stop)
    $KUBECTL_CMD -n default delete pod,svc --all
    ;;
  logdns)
    $KUBECTL_CMD logs --follow -n kube-system --selector 'k8s-app=kube-dns'
    ;;
  restart-mk8)
    sudo snap disable microk8s
    sudo snap enable microk8s
    ;;
  services)
    $KUBECTL_CMD get services --all-namespaces -o wide
    ;;
  ns)
    $KUBECTL_CMD get all --all-namespaces
    ;;
  build) # Expects Argument APP_ID
    DOCKER_TAG_NAME=${2:-"DOCKER TAG MISSING"}
    _buildContainer $DOCKER_TAG_NAME
    ;;
  push)
    BUILD_DIR=$2
    _pushContainer $BUILD_DIR
    ;;
  logs)
    kubectl logs -n airflow -f worker-57f869d7c6-2cjfx
    ;;
  docker-del-all)
    docker rmi $(docker images -q) -f
    docker system prune --all --force
    ;;
  port-forward)
    K8S_RESOURCE="deployment/webserver"
    NAME_SPACE="airflow"
    IP_ADDR=`hostname -i`
    SRC_PORT="8888"
    DST_PORT="8080"
    # netstat -ltnp
    echo "Forwarding $SRC_PORT to $DST_PORT on $IP_ADDR for $NAME_SPACE - $K8S_RESOURCE"
    pkill -f 'kubectl port-forward'
    nohup microk8s.kubectl port-forward --address $IP_ADDR --namespace $NAME_SPACE $K8S_RESOURCE $SRC_PORT:$DST_PORT &
    ps -ef | grep port-forward
    ;;
  k8s-install)
    sudo snap install microk8s --classic
    microk8s start
    microk8s.enable dns
    microk8s.enable metrics-server
    #microk8s.enable dashboard
    ;;
  get-metrics)
    microk8s.enable get --raw /apis/metrics.k8s.io/v1beta1/pods
    ;;
  dashboard-token)
    token=$(microk8s.kubectl -n kube-system get secret | grep default-token | cut -d " " -f1)
    microk8s.kubectl -n kube-system describe secret $token
    # kc proxy
    # ssh -N -L 8888:localhost:8001 r-apps
    # http://localhost:8888/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/login
    ;;
  help)
    echo "create, stop, restart, list, delete"
    ;;
  hold)
    _holdContainerOpen
    ;;
  *)
    echo "Not Found " "$@"
    ;;
esac
