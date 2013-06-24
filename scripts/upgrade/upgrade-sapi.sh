#!/usr/bin/bash
#
# upgrade-sapi.sh: provision a new SAPI instance

set -o xtrace
set -o errexit

if [[ $# -ne 0 ]]; then
    echo "usage: $0"
    exit 1
fi

source ./images.sh

if [[ -z ${SAPI_IMAGE} ]] ; then
    echo "error: \$SAPI_IMAGE not defined"
    exit 1
fi


# (1) Check to make sure SAPI hasn't already been upgraded

CURRENT_IMAGE=$(vmadm get $(vmadm lookup alias=~sapi)| json image_uuid)
if [[ $CURRENT_IMAGE == $SAPI_IMAGE ]]; then
    echo "SAPI already using image $CURRENT_IMAGE"
    exit 0
fi


# (2) Install latest SAPI image

./download-image.sh ${SAPI_IMAGE}


# (3) Fix up SAPI's SAPI service to refer to new image

echo "{
    \"params\": {
        \"image_uuid\": \"${SAPI_IMAGE}\"
    }
}" > /tmp/changes.$$.json

SAPI_SVC_UUID=$(sdc-sapi /services?name=sapi | json -Ha uuid | head -n 1)
sdc-sapi /services/${SAPI_SVC_UUID} -X PUT -T /tmp/changes.$$.json


# (4) Provision a new SAPI instance

orig=$(vmadm get $(vmadm lookup alias=~sapi) | json alias |
    sed 's/sapi\([0-9]\)/\1/')
new=$(( $orig + 1 ))

echo "
{
    \"service_uuid\": \"${SAPI_SVC_UUID}\",
    \"params\": {
        \"alias\": \"sapi${new}\"
    }
}" | sapiadm provision


# (5) Restart SAPI to workaround lack of appropriate post_cmd

sleep 35
SAPI1_UUID=$(vmadm lookup alias=sapi${new})
zlogin ${SAPI1_UUID} svcadm restart sapi


# (6) Destroy the original SAPI instance

SAPI0_UUID=$(vmadm lookup alias=sapi${orig})
SAPI1_IP=$(vmadm get $(vmadm lookup alias=sapi${new}) | json nics.0.ip)
curl http://${SAPI1_IP}/instances/${SAPI0_UUID} -X DELETE

sleep 60  # to allow DNS record for sapi0 to expire


# (7) Fix up sapiadm symlink

SAPI_UUID=$(vmadm lookup alias=~sapi)

rm -f /opt/smartdc/bin/sapiadm

ln -s \
    /zones/${SAPI_UUID}/root/opt/smartdc/config-agent/cmd/sapiadm.js \
    /opt/smartdc/bin/sapiadm
