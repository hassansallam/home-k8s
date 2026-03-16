#cloud-config

hostname: ${hostname}
manage_etc_hosts: true
ssh_pwauth: true

users:
  - name: alpine
    shell: /bin/ash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    # default password: alpine (change on first login)
    passwd: "$6$rounds=4096$abc123$VyEKAlTBkBMmYT.ZRlPqOcnbGqXOZMgJBP8LnmalrHvvzv5Ss/MHpfBSaN.11VIqcqQxDE9l5LwMNb6aAJTjR0"
    ssh_authorized_keys:
      - ${ssh_pubkey}

package_update: true

packages:
  - haproxy

write_files:
  - path: /etc/resolv.conf
    owner: root:root
    permissions: "0644"
    content: |
      nameserver ${dns_server}

  - path: /etc/haproxy/haproxy.cfg
    owner: root:root
    permissions: "0644"
    content: |
      global
          log /dev/log local0
          log /dev/log local1 notice
          maxconn 4096
          daemon

      defaults
          log     global
          mode    tcp
          option  tcplog
          option  dontlognull
          timeout connect 5s
          timeout client  60s
          timeout server  60s
          retries 3

      frontend k8s_api
          bind *:6443
          default_backend k8s_api_backend

      backend k8s_api_backend
          balance roundrobin
          option tcp-check
%{ for i, ip in controlplane_ips ~}
          server cp${i + 1} ${ip}:6443 check fall 3 rise 2
%{ endfor ~}

      frontend talos_api
          bind *:50000
          default_backend talos_api_backend

      backend talos_api_backend
          balance roundrobin
%{ for i, ip in controlplane_ips ~}
          server cp${i + 1} ${ip}:50000 check inter 5s fall 3 rise 2
%{ endfor ~}

      frontend stats
          bind *:8404
          mode http
          stats enable
          stats uri /stats
          stats refresh 10s
          stats admin if LOCALHOST

runcmd:
  - rc-update add haproxy default
  - rc-service haproxy start
