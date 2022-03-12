#cloud-config
#
# package update and upgrade
package_update: true
package_upgrade: true
#
# install packages
packages:
  - docker
  - docker.io
  - docker-compose
#
# users
users:
  - default
  - name: odm
    sudo:  ALL=(ALL) NOPASSWD:ALL
    groups: docker
    ssh_authorized_keys:
      - ${ssh_key}
#
# run commands
runcmd:
  - sudo mkdir -p /odm/data
  - git clone https://github.com/OpenDroneMap/WebODM --config core.autocrlf=input --depth 1 /odm/WebODM
  - sudo chown -R odm:odm /odm
  - sudo --set-home --user=odm docker network create --subnet=172.20.0.0/16 odmnetwork
  - sudo --set-home --user=odm docker run --detach --rm --network odmnetwork --ip 172.20.0.10 --tty --publish 3000:3000 --publish 8001:10000 --publish 8080:8080 opendronemap/clusterodm
  - sudo --set-home --user=odm docker run --detach --rm --network odmnetwork --ip 172.20.0.11 --publish 3001:3000 opendronemap/nodeodm
  - sudo --set-home --user=odm /odm/WebODM/webodm.sh start --detached --default-nodes 0 --media-dir /odm/data
#
# end of config