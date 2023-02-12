#!/usr/bin/env bash

### Argumant and ussage setup
#######################################
usage() {
  cat <<EOF
  usage: $0 [ OPTIONS ] [ -- Additional Docker Build Options ]
  Options
  -h  --help      Show this message and exit
  -t  --tag       Build with a specific docker tag
  -x  --debug     Set the bash debug flag

  Example:

  $0 --tag devel -- "--build-arg=OSDCTL_VERSION=tags/v0.4.0 --build-arg=ROSA_VERSION=v1.0"

EOF
}

BUILD_TAG="latest"
CONTAINER_ARGS=()

while [ "$1" != "" ]; do
  case $1 in
    -h | --help )           usage
                            exit 1
                            ;;
    -t | --tag )            shift
                            BUILD_TAG=$1
                            ;;
    -x | --debug )          set -x
                            ;;

    -- ) shift
      CONTAINER_ARGS+=($@)
      break
      ;;

    -* ) echo "Unexpected parameter $1"
        usage
        exit 1
        ;;

    * ) echo "Unexpected parameter $1"
        usage
        exit 1
  esac
  shift
done


### Load config
export OCM_CONTAINER_CONFIG="${HOME}/.config/ocm-container/env.source"
if [ ! -f ${OCM_CONTAINER_CONFIG} ]; then
    echo "Cannot find config file, exiting";
    exit 1;
fi
source ${OCM_CONTAINER_CONFIG}

if [[ "$OS_ARCH" == "arm64" ]]; then
  export CONTAINER_CONNECTION=${OCM_PODMAN_VM}
fi

### cd to repo
cd $(dirname $0)

### Make sure the podman virtual machine is initialised and running
### Only required for arm64 / M1
if [[ "$OS_ARCH" == "arm64" ]]; then
  if ! podman-vm-m1; then
    exit 1
  fi
fi

echo "All GOOD"

### start build
# for time tracking
date
date -u

# podman build --build-arg ARCH=arm64 -t ocm-container:latest .
# we want the $@ args here to be re-split
time ${CONTAINER_SUBSYS} build \
  --build-arg ARCH=arm64 \
  $CONTAINER_ARGS \
  -t ocm-container:${BUILD_TAG} \
  -f Containerfile .

# # for time tracking
# date
# date -u

