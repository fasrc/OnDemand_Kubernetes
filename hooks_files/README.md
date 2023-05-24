## Add hooks

### Files changed 
- Updated `hook.env`
- Added a new file `pre-hook.sh`
- Updated `hooks/k8s-bootstrap/yaml/rolebinding.yaml`

`hook.env` file in this folder is for reference only; the same file can be found in eks/templates folder.
`hook.env` in  eks/templates folder should be used by eks/deploy.sh to create `hook.env` that will be copied to 
the ood server to `/etc/ood/config/hook.env`; 
The copy of the hooks files can be found in in the ood installation script.


---

Edit `pod.yml.erb` in `lib/ood_core/job/adapters/kubernetes/templates/pod.yml.erb`

```
VERSION="2.0.13"
OOD_CORE="ood_core-0.17.2"
vim  /opt/ood/ondemand/root/usr/share/gems/2.7/ondemand/${VERSION}/gems/${OOD_CORE}/lib/ood_core/job/adapters/kubernetes/templates/pod.yml.erb
```
 
Comment `startupProbe` section on pod template binding the section inside `<% if false %>...<% end %>`

```
  <% if false %>
  startupProbe:
    tcpSocket:
      port: <%= spec.container.startup_probe.port %>
    initialDelaySeconds: <%= spec.container.startup_probeinitial_delay_seconds %>
    failureThreshold: <%= spec.container.startup_probefailure_threshold %>
    periodSeconds: <%= spec.container.startup_probeperiod_seconds %>
  <% end %>
```
