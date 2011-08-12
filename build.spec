{
    "platform-release": "master"
  , "hvm-platform-release": "HVM"
  , "hvm-subdir": "release-20110714"
  , "use-proxy": "false"
  , "proxy-ip": "10.0.1.138"
  , "build-tgz": "true"
  , "build-hvm": "true"
  , "agents-shar": "master"
  , "hvm-agents-shar": "hvm"
  , "datasets": [
      { "name": "smartos-1.3.15"
      , "uuid": "184c9b38-ad3d-11e0-bad6-1b7240aaa5fc"
      , "headnode_zones": "true"
      }
    , { "name": "nodejs-1.1.4"
      , "uuid": "41da9c2e-7175-11e0-bb9f-536983f41cd8"
      }
    , { "name": "ubuntu-10.04.2.6"
      , "uuid": "2214e5f8-4e5d-2a4f-8f72-c4599daa1d28"
      }
  ]
  , "adminui-checkout": "origin/master"
  , "atropos-tarball": "^atropos-develop-.*.tar.bz2$"
  , "ca-tarball": "^ca-pkg-master-.*.tar.bz2$"
  , "capi-checkout": "origin/master"
  , "dhcpd-checkout": "origin/master"
  , "mapi-checkout": "origin/master"
  , "portal-checkout": "origin/master"
  , "cloudapi-checkout": "origin/master"
  , "pubapi-checkout": "origin/master"
  , "rabbitmq-checkout": "origin/master"
  , "upgrades": {
      "agents": [
          "atropos/master/atropos-master-*"
        , "cloud_analytics/master/cabase-master-*"
        , "cloud_analytics/master/cainstsvc-master-*"
        , "dataset_manager/master/dataset_manager-master-*"
        , "heartbeater/master/heartbeater-master-*"
        , "provisioner/master/provisioner-master-*"
        , "smartlogin/master/smartlogin-master-*"
        , "zonetracker/master/zonetracker-master-*"
      ]
  }
}
