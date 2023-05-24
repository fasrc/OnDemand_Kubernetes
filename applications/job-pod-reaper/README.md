# job-pod-reaper

Kubernetes service that can reap pods that have run past their lifetime.

This reaping is intended to be run against pods that act like short lived jobs.  Additional resources with the same `job` label as the expired pod will also be reaped.

Current list of resources that can be reaped:

* Pod
* Service
* ConfigMap
* Secret

Metrics about the count of reaped resources, duration of last reaping, and error counts can be queried using Prometheus `/metrics` endpoint exposed as a Service on port `8080`.

## Install

### Install with YAML via login into OOD web node

First install the necessary Namespace and RBAC resources:

```
kubectl apply -f https://github.com/OSC/job-pod-reaper/releases/latest/download/namespace-rbac.yaml
```

For Open OnDemand a deployment can be installed using Open OnDemand specific deployment:

```
kubectl apply -f https://github.com/OSC/job-pod-reaper/releases/latest/download/ondemand-deployment.yaml
```

A more generic deployment:

```
kubectl apply -f https://github.com/OSC/job-pod-reaper/releases/latest/download/deployment.yaml
```

## Configuration

To give a lifetime to your pods, add the following annotation:

`pod.kubernetes.io/lifetime: $DURATION`

`DURATION` has to be a [valid golang duration string](https://golang.org/pkg/time/#ParseDuration).

Example: `pod.kubernetes.io/lifetime: 24h`