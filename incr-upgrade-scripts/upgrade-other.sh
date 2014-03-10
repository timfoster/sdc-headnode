#!/usr/bin/bash
#
# Upgrade other "stuff". Manual upgrade requirements that come up.
# See the "other upgrades" section in README.md.
#

if [[ -n "$TRACE" ]]; then
    export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -o xtrace
fi
set -o errexit
set -o pipefail


#---- support stuff

function fatal
{
    echo "$0: fatal error: $*"
    exit 1
}


#---- mainline

# -- HEAD-1910, OS-2654: maintain_resolvers=true

# 1. Update the sapi services.
SDC_APP=$(sdc-sapi /applications?name=sdc | json -H 0.uuid)
[[ -n "$SDC_APP" ]] || fatal "could not determine 'sdc' SAPI app"
for data in $(sdc-sapi /services?application_uuid=$SDC_APP | json -H -a uuid name params.maintain_resolvers -d,); do
    svc_uuid=$(echo "$data" | cut -d, -f1)
    svc_name=$(echo "$data" | cut -d, -f2)
    maintain_resolvers=$(echo "$data" | cut -d, -f3)
    if [[ "$maintain_resolvers" != "true" ]]; then
        echo "Set params.maintain_resolvers on service $svc_uuid ($svc_name)."
        echo '{"params": {"maintain_resolvers": true}}' | sapiadm update $svc_uuid
    fi
done

# TODO(HEAD-1910): only do the upgrade for core VMs that are on a platform
# >=  20140212T195911Z.
#
## 2. Update current core VMs. To work, this depends on ZAPI-472,
##    https://mo.joyent.com/vmapi/commit/8f3a47d, which added 'update' workflow
##    version 7.0.7. So we need at least that version.
#ufds_admin_uuid=$(bash /lib/sdc/config.sh -json | json ufds_admin_uuid)
#update_workflow_vers=$(sdc-workflow /workflows \
#    | json -Ha -c '/^update-[\d\.]+$/.test(this.name)' -e 'this.ver=this.name.split("-").slice(-1)[0]' ver | sort)
## TODO: I'm not sure how to check semver *greater than or equal* to 7.0.7,
##       so just checking for 7.0.7 presence.
#if [[ "$(echo "$update_workflow_vers" | grep '7\.0\.7' || true)" == "7.0.7" ]]; then
#    sdc-vmapi /vms?state=active\&owner_uuid=$ufds_admin_uuid \
#        | json -Ha uuid alias maintain_resolvers \
#        | while read uuid alias maintain_resolvers; do
#        if [[ "$maintain_resolvers" != "true" ]]; then
#            echo "Set maintain_resolvers=true on VM $uuid ($alias)."
#            sdc-vmapi /vms/$uuid?action=update -X POST -d '{"maintain_resolvers": true}' \
#                | sdc sdc-waitforjob
#        fi
#    done
#else
#    echo "Skip HEAD-1910 upgrade until VMAPI upgraded with ZAPI-472."
#fi


# -- HEAD-1916: SERVICE_DOMAIN on papi svc, PAPI_SERVICE/papi_domain on sdc app

SDC_APP=$(sdc-sapi /applications?name=sdc | json -H 0.uuid)
DOMAIN=$(sdc-sapi /applications/$SDC_APP | json -H metadata.datacenter_name).$(sdc-sapi /applications/$SDC_APP | json -H metadata.dns_domain)
papi_domain=papi.$DOMAIN

sapi_url=$(sdc-sapi /applications/$SDC_APP | json -H metadata.sapi-url)
papi_service=$(sdc-sapi /services?name=papi | json -H 0.uuid)
if [[ -n "$papi_service" ]]; then
    echo "Upgrade PAPI service vars in SAPI."
    sapiadm update $papi_service metadata.SERVICE_DOMAIN=$papi_domain
    sapiadm update $papi_service metadata.sapi-url=$sapi_url
    sapiadm update $SDC_APP metadata.PAPI_SERVICE=$papi_domain
    sapiadm update $SDC_APP metadata.papi_domain=$papi_domain
fi


mahi_domain=mahi.$DOMAIN

sapi_url=$(sdc-sapi /applications/$SDC_APP | json -H metadata.sapi-url)
mahi_service=$(sdc-sapi /services?name=mahi | json -H 0.uuid)
if [[ -n "$mahi_service" ]]; then
    echo "Upgrade MAHI service vars in SAPI."
    sapiadm update $mahi_service metadata.SERVICE_DOMAIN=$mahi_domain
    sapiadm update $mahi_service metadata.sapi-url=$sapi_url
    sapiadm update $SDC_APP metadata.MAHI_SERVICE=$mahi_domain
    sapiadm update $SDC_APP metadata.mahi_domain=$mahi_domain
fi


# -- INTRO-701, should have at last 4GiB mem cap on ca zone

ca_svc=$(sdc-sapi /services?name=ca | json -H 0.uuid)
ca_max_physical_memory=$(sdc-sapi /services/$ca_svc | json -H params.max_physical_memory)
if [[ $ca_max_physical_memory != "4096" ]]; then
    echo "Update 'ca' SAPI service max_physical_memory, etc."
    sapiadm update $ca_svc params.max_physical_memory=4096
    sapiadm update $ca_svc params.max_locked_memory=4096
    sapiadm update $ca_svc params.max_swap=8192
    sapiadm update $ca_svc params.zfs_io_priority=20
    sapiadm update $ca_svc params.cpu_cap=400
    sapiadm update $ca_svc params.package_name=sdc_4096
fi
ca_zone_uuid=$(vmadm lookup -1 state=running alias=ca0)
ca_zone_max_physical_memory=$(vmadm get $ca_zone_uuid | json max_physical_memory)
if [[ $ca_zone_max_physical_memory != "4096" ]]; then
    echo "Update 'ca0' zone mem cap to 4096."
    vmadm update $ca_zone_uuid max_physical_memory=4096
    vmadm update $ca_zone_uuid max_locked_memory=4096
    vmadm update $ca_zone_uuid max_swap=8192
    vmadm update $ca_zone_uuid zfs_io_priority=20
    vmadm update $ca_zone_uuid cpu_cap=400
fi
