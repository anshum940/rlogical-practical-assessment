# Troubleshooting and Operational Approach

## General method

I would first confirm the impact, affected scope, start of symptoms, and recent changes. I would avoid restarting or changing configuration until I had captured current state, logs, events, resource use, and the exact failing request. For a production incident, I would communicate status, preserve evidence, make one reversible change at a time, and compare the result with a known-good baseline.

## Scenario A - Pod is `Running` but `READY 0/1`

`Running` means the Pod has been scheduled and at least one container process is running. `0/1` means its container is not ready to receive Service traffic. I would therefore start with readiness state and events rather than assuming the process is down.

```bash
kubectl get pod <pod> -n <namespace> -o wide
kubectl describe pod <pod> -n <namespace>
kubectl get events -n <namespace> --field-selector involvedObject.name=<pod> --sort-by=.metadata.creationTimestamp
kubectl logs <pod> -n <namespace> --all-containers
kubectl logs <pod> -n <namespace> --all-containers --previous
```

I would inspect the readiness-probe failure text, restart count, container state, image, mounted configuration, environment references, and resource limits. If the probe reports an HTTP failure, timeout, or connection refusal, I would compare its path, port, scheme, initial delay, and timeout with the application's actual listener and startup behavior.

```bash
kubectl get pod <pod> -n <namespace> -o jsonpath='{.status.containerStatuses}'
kubectl get pod <pod> -n <namespace> -o yaml
kubectl exec -n <namespace> <pod> -- sh -c 'ss -lntp; wget -qO- http://127.0.0.1:<port>/<health-path>'
kubectl top pod <pod> -n <namespace> --containers
```

If the image has no diagnostic tools, I would use `kubectl debug` with an approved ephemeral image instead of modifying the application container. Results determine the next branch:

- **Wrong probe path/port/scheme:** correct the Deployment and roll it out.
- **Application is still starting:** inspect dependency/startup latency, then tune a startup probe rather than hiding a fault with a large readiness delay.
- **Application is listening only on the wrong interface:** configure it to listen on the Pod interface or `0.0.0.0` as appropriate.
- **Dependency failure:** test DNS, network reachability, credentials/config references, and the dependent service from the Pod namespace.
- **CPU throttling, memory pressure, OOM, or repeated restarts:** compare usage with requests/limits, inspect node pressure and termination reason, then fix the workload or right-size resources.

I would finish by watching the rollout and confirming the Pod becomes Ready without recurring events:

```bash
kubectl rollout status deployment/<deployment> -n <namespace>
kubectl get pods -n <namespace> -w
```

## Scenario B - Pods work but the Kubernetes Service does not

I would first confirm where the client is located. A `ClusterIP` Service is intentionally reachable only inside the cluster. From an in-cluster diagnostic Pod, I would compare direct Pod access with Service DNS and ClusterIP access.

```bash
kubectl get service <service> -n <namespace> -o yaml
kubectl describe service <service> -n <namespace>
kubectl get pods -n <namespace> --show-labels
kubectl get endpointslices -n <namespace> -l kubernetes.io/service-name=<service> -o wide
kubectl run service-debug --rm -it --restart=Never -n <namespace> --image=curlimages/curl -- sh
```

From the diagnostic Pod:

```bash
curl -v http://<pod-ip>:<container-port>/
curl -v http://<service-name>:<service-port>/
getent hosts <service-name>
```

The comparison narrows the cause:

- **No EndpointSlices/endpoints:** compare the Service selector with Pod labels and verify Pods are Ready. A selector or readiness mismatch is the likely cause.
- **Endpoints exist but direct Pod access fails:** check the application listener, container port, Pod firewall, and process logs.
- **Pod access works but Service access fails:** verify `port`, `targetPort`, protocol, and named-port spelling; then inspect NetworkPolicies and the cluster's service proxy/CNI health.
- **ClusterIP works but DNS name fails:** check the namespace-qualified name and CoreDNS health/logs.
- **Only external access fails:** confirm this is expected for `ClusterIP`; use an approved Ingress, Gateway, LoadBalancer, or port-forward for the required exposure instead of changing the Service blindly.

After a fix, I would recheck EndpointSlices and repeat both Pod-IP and Service requests from a clean diagnostic Pod.

## Scenario C - Nginx returns `502 Bad Gateway`

A 502 normally means Nginx accepted the client request but could not obtain a valid response from the configured upstream. I would preserve the exact error-log message because `connection refused`, timeout, name-resolution failure, and protocol errors require different fixes.

```bash
sudo nginx -t
sudo journalctl -u nginx --no-pager -n 100
sudo tail -n 100 /var/log/nginx/error.log
sudo ss -lntp | grep ':3000'
curl -v http://127.0.0.1:3000/health
sudo systemctl status <application-service> --no-pager
sudo journalctl -u <application-service> --no-pager -n 100
```

I would then branch on the evidence:

- **Connection refused:** start/fix the backend, correct its port, or correct `proxy_pass`. Confirm the process is actually listening.
- **Timeout:** inspect application latency, dependency calls, CPU/memory pressure, connection backlog, and Nginx upstream timeout settings. I would not merely increase timeouts until the slow component is understood.
- **Wrong protocol or malformed response:** match `http://` versus `https://`, TLS/SNI settings, and upstream application behavior.
- **Permission denied:** inspect Nginx service confinement, file/socket permissions, AppArmor/SELinux policy, and the service user.
- **Containerized components:** remember that `127.0.0.1` means the current container/network namespace. Separate containers should normally use a shared network and backend service/container DNS name; the supplied assessment configuration requires localhost and was validated with both processes sharing one network namespace.

After correcting the root cause, I would run `nginx -t`, reload rather than restart when safe, call the backend directly, call through Nginx, and check that the error rate returns to baseline.

## Scenario D - Ubuntu server is slow and the application is unavailable

I would first determine whether this is host-wide saturation, one application, storage/network dependency, or a recent deployment. I would not clear caches, delete files, or restart the server before collecting evidence.

### 1. Establish host state and pressure

```bash
uptime
top -b -n 1
ps -eo pid,ppid,user,stat,%cpu,%mem,etime,cmd --sort=-%cpu | head
free -h
vmstat 1 5
df -hT
df -ih
sudo dmesg -T | tail -n 100
```

High load with high CPU points toward compute saturation or a runaway process. High load with idle CPU and blocked tasks suggests storage or network I/O. Low available memory, sustained swap, or OOM messages points toward memory pressure. Full space or inodes can prevent logs, sockets, PID files, database writes, and deployments.

For storage latency I would use `iostat -xz 1 5` if the existing `sysstat` package is available; I would not install tools during an incident without approval. I would use `du` only on the affected filesystem and avoid crossing mounts:

```bash
sudo du -xhd1 /var | sort -h
sudo journalctl --disk-usage
```

I would identify retention or runaway output before removing anything and preserve logs needed for root-cause analysis.

### 2. Check the application and service manager

```bash
sudo systemctl status <service> --no-pager
sudo systemctl show <service> -p ActiveState,SubState,Result,ExecMainStatus,NRestarts
sudo journalctl -u <service> --no-pager -n 200
ps -ef | grep '[a]pplication-process'
sudo ss -lntp
curl -v --max-time 5 http://127.0.0.1:<port>/health
```

If the service is failed, I would inspect its exit status, configuration, dependency availability, permissions, and the first error before considering a controlled restart. If it is active but not listening, I would inspect startup logs and process state. If localhost works but users fail, I would move outward through Nginx/load balancer, firewall/security-group rules, DNS, and routing.

### 3. Check network and dependencies

```bash
ip -brief address
ip route
ss -s
getent hosts <dependency-host>
curl -v --connect-timeout 3 <dependency-health-url>
sudo journalctl -u systemd-resolved --no-pager -n 100
```

I would check connection counts, listen queues, DNS resolution, packet loss/latency, exhausted file descriptors, and database/cache/API health. If only remote access fails, I would compare local, same-subnet, and external requests and inspect the relevant host firewall and cloud network controls.

### 4. Check permissions and recent change

```bash
namei -l <required-path>
sudo -u <service-user> test -r <required-file>
sudo -u <service-user> test -w <required-directory>
sudo journalctl --since '<incident-start>' --no-pager
```

I would compare the active release, environment/configuration, packages, certificates, mounts, and service unit with the last known-good state. A confirmed bad deployment should use the documented rollback, not an unreviewed live edit.

### 5. Recover and verify

The remediation depends on the proven bottleneck: stop or limit a runaway process, restore capacity, correct permissions/configuration, recover a dependency, scale safely, or roll back. Afterward I would verify host pressure, service state, listening port, direct and proxied health checks, user-visible behavior, logs, and monitoring. I would document the timeline, root cause, contributing controls, and a preventive action with an owner.

## References

- Kubernetes application debugging: https://kubernetes.io/docs/tasks/debug/debug-application/
- Kubernetes Service debugging: https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/
- Kubernetes probes: https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/
- NGINX proxy module: https://nginx.org/en/docs/http/ngx_http_proxy_module.html
- Ubuntu systemd service troubleshooting uses the standard `systemctl` and `journalctl` interfaces documented by their installed manual pages.
