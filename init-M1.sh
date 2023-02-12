#!/usr/bin/env bash

usage() {
  cat <<EOF
  usage: $0 [ OPTIONS ] [ -- Additional Docker Build Options ]
  Options
  -h  --help      Show this message and exit
  -f  --force     Update all congigurations even if they exist already
  -r  --rebuild   Rebuild the podman virtual machine
  -x  --debug     Set the bash debug flag

  Example:

  $0 --tag devel -- "--build-arg=OSDCTL_VERSION=tags/v0.4.0 --build-arg=ROSA_VERSION=v1.0"

EOF
}

BUILD_TAG="latest"
CONTAINER_ARGS=()
FORCE=false
REBUILD=false

while [ "$1" != "" ]; do
  case $1 in
    -h | --help )           usage
                            exit 1
                            ;;
    -f | --force )          shift
                            FORCE=true
                            ;;
    -r | --rebuild )        shift
                            REBUILD=true
                            ;;
    -x | --debug )          set -x
                            ;;

    -- ) shift
      CONTAINER_ARGS+=($@)
      break
      ;;

    -* ) echo "Unexpected flag '$1'"
        usage
        exit 1
        ;;

    * ) echo "Unexpected argument '$1'"
        usage
        exit 1
  esac
  shift
done

export OS_ARCH=$(uname -m)
export OS_OS=$(uname -o)

cd $(dirname $0)
CONFIG_DIR=${HOME}/.config/ocm-container

# Create ocm configuration file
if [ ! -f ${CONFIG_DIR}/env.source ]; then
  echo "Creating default Configuration"
  mkdir -p ${CONFIG_DIR}
  cp env.source.sample ${CONFIG_DIR}/env.source
else
  echo "ocm-container configuration file already already exists."
  if [[ "$FORCE" == true ]]; then
    echo "FORCE: Replacing configuration file with template"
    if [[ ! -f ${CONFIG_DIR}/env.$(date "+%Y-%m-%d").source ]]; then
      echo "Saving exisiting file to ${CONFIG_DIR}/env.$(date "+%Y-%m-%d").source"
      cp ${CONFIG_DIR}/env.source ${CONFIG_DIR}/env.$(date "+%Y-%m-%d").source
    fi
    cp -f env.source.sample ${CONFIG_DIR}/env.source
  fi
fi

# Add ocm-container run script to PATH
if [[ ! -L /usr/local/bin/ocm-container ]] || [[ "$FORCE" == true ]]; then
  if [[ "$FORCE" == true ]]; then
    echo -n "FORCE: Replacing OR "
  fi
  echo "Creating symlink for ocm-container binary (requires sudo permissions to access /usr/local/bin/...)"
  sudo ln -sfn "$(pwd)/ocm-container-m1.sh" /usr/local/bin/ocm-container
else
  echo "Symlink to ocm-container binary already exist."
fi

# Add the additional vm script for M1 (arm64). Only equired for podman on M1

echo "HW-01"
if [[ "$OS_ARCH" == "arm64" ]]; then
  echo "HW-02"
  if [[ ! -L /usr/local/bin/podman-vm-m1 ]] || [[ "$FORCE" == true ]]; then
    echo "HW-03"
    if [[ "$FORCE" == true ]]; then
      echo -n "FORCE: Replacing OR "
    fi
    echo "HW-04"
    echo "Creating symlink for podman-vm-m1.sh binary (requires sudo permissions to access /usr/local/bin/...)"
    sudo ln -sfn "$(pwd)/podman-vm-m1.sh" /usr/local/bin/podman-vm-m1
  else
    echo "Symlink to podman-vm-m1.sh binary already exist."
  fi
fi


echo
echo
echo "ocm-container configuration can be customized by editing ${CONFIG_DIR}/env.source"
# Check if the required variables hve been added
source ${CONFIG_DIR}/env.source
NOT_COMPLETE_ENV=false

if [[ "$OS_ARCH" == "arm64" ]] && [[ ! -n "$OCM_PODMAN_VM" ]]; then
  NOT_COMPLETE_ENV=true
  echo
  echo "REQUIRED: The 'OCM_PODMAN_VM' variable is required for M1 MBP.  Please un comment or set this variable in '${CONFIG_DIR}/env.source'"
  echo
fi

if [[ $( grep -c '^# REQUIRED:' "${CONFIG_DIR}/env.source") -ne 0 ]]; then
  echo
  echo "it seems that in '${CONFIG_DIR}/env.source' there are some configurations that are not fufilled"
  echo "please remove the REQUIRED line once they are set:"
  echo
  AWK=$( cat << EOF
/^# REQUIRED:/
  {
    print FILENAME ":" NR, \$0;
    tmpfs=FS;
    FS="=";
    getline;
    print FILENAME ":" NR, \$1 "=";
    FS=tmpfs;
    print "";
  }
EOF
)
  awk -f <( echo $AWK ) "${CONFIG_DIR}/env.source"
  NOT_COMPLETE_ENV=true
fi

if [[ "$NOT_COMPLETE_ENV" == true ]]; then
  exit 1
fi

### Make sure the podman virtual machine is initialised
### Only required for arm64 / M1
if [[ "$OS_ARCH" == "arm64" ]]; then
  CREATE_VM=false
  echo
  echo "Checking for existing podman VM"
  if ${CONTAINER_SUBSYS} machine inspect ${OCM_PODMAN_VM} > /dev/null 2>&1; then
    echo "The podman VM '${OCM_PODMAN_VM}' for ocm-container already exists"
    if [[ "$REBUILD" == true ]]; then
      echo "REBUILD: Removing previous container '${OCM_PODMAN_VM}'"
      ${CONTAINER_SUBSYS} machine rm --force ${OCM_PODMAN_VM}
      echo "Creating the podman VM..."
      CREATE_VM=true
    fi
  else
    echo
    echo "The podman VM '${OCM_PODMAN_VM}' does not exist.  Creating the podman VM..."
    CREATE_VM=true
  fi
  if [[ "$CREATE_VM" == "true" ]]; then
    ${CONTAINER_SUBSYS} machine init ${OCM_PODMAN_VM} -v ${HOME}:${HOME} -v /private:/private > /dev/null
  fi
fi

echo
echo
echo "Initialisation has completed.  The build scipt can be run next"
