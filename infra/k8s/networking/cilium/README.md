# BGP configuration on UniFi

```bash
router bgp 64513
  bgp router-id 192.168.40.1
  no bgp ebgp-requires-policy

  ! Kubernetes peer group
  neighbor k8s peer-group
  neighbor k8s remote-as 64514

  ! Add each Kubernetes node
  neighbor 192.168.40.11 peer-group k8s
  neighbor 192.168.40.11 description "node-01"

  neighbor 192.168.40.12 peer-group k8s
  neighbor 192.168.40.12 description "node-02"

  neighbor 192.168.40.13 peer-group k8s
  neighbor 192.168.40.13 description "node-03"

  ! IPv4 unicast address family
  address-family ipv4 unicast
    neighbor k8s next-hop-self
    neighbor k8s soft-reconfiguration inbound
  exit-address-family
exit
```
