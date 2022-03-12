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
  - sudo --set-home --user=odm docker network create --subnet=172.20.0.0/16 odmnetwork
  - sudo --set-home --user=odm docker run --detach --rm --network odmnetwork --ip 172.20.0.11 --publish 3000:3000 opendronemap/nodeodm
#
# end of config