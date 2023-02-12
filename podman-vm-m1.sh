#!/usr/bin/env bash

### Start the podman-vm created for ocm-container
# This is only required for MBP - OS == Darwin

if [[ $(uname) != "Darwin" ]]; then
  echo "A virtual machine for podman is only required for specific achitectures"
  FAILED=false
  START_VM=false
else
  if ${CONTAINER_SUBSYS} machine inspect ${OCM_PODMAN_VM} > /dev/null 2>&1; then
    echo "The ocm-container VM for podman exists"
    if ${CONTAINER_SUBSYS} machine list | grep -q "Currently running"; then 
      # Podman is running a vm service
      if ${CONTAINER_SUBSYS} machine list | grep "Currently running" | grep -q ${OCM_PODMAN_VM}; then
        echo "The podman VM for ocm-container is running"
        FAILED=false
        START_VM=false
      else
        RUNNING_VM=$(${CONTAINER_SUBSYS} machine list | grep "Currently running" | cut -d '*' -f 1)
        echo "The podman VM for ocm-container is NOT running"
        read -n 1 -p "The VM '${RUNNING_VM}' is currently running.  Shutdown this VM and start the VM for ocm-container?[y/n]: " SELECTION
        echo
        if [[ "$SELECTION" == y ]]; then
          ${CONTAINER_SUBSYS} machine stop ${RUNNING_VM}
        else
          echo "Exiting: The build can not contiune as the podman VM for ocm-container is not running"
          FAILED=true
        fi
      fi
    else
      # Podman is not running a VM service
      echo "Starting the podman VM service"
      ${CONTAINER_SUBSYS} machine start ${OCM_PODMAN_VM}
    fi
  else
    echo "The ocm-container VM for podman does not exist, run init-M1.sh to ensure the environment is setup"
    FAILED=true
    START_VM=false
  fi
fi

if [[ "$START_VM" == true ]]; then
  if ${CONTAINER_SUBSYS} machine start ${OCM_PODMAN_VM} ; then
    FAILED=false
  else
    FAILED=true
  fi
fi

if [[ "$FAILED" == true ]]; then
  echo "FAILURE: The virtual marachine could not be started"
  exit 1
fi
