version: 1
config:
  - type: physical
    name: eth0
    subnets:
      - type: static
        address: ${ip_address}/24
        gateway: ${gateway}
        dns_nameservers:
          - ${dns_server}
