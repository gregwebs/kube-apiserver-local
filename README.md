Local K8s data storage without Docker

Run kube-apiserver locally without Docker.
Data is stored via kubebrain in a local storage engine.

Only kube-apiserver is running: no pods will be scheduled.
This is useful for testing k8s data storage.

Run with:

```
./apiserver.sh
```

That will run kubebrain in the background and launch kube-apiserver.
It sets up some certificates for kubernetes.

To connect with kubectl, first generate a kubeconfig

```
./kubeconfig.sh
```

You can then connect via kubectl with:

```
KUBECONFIG=admin.kubeconfig kubectl get all
```

## Purpose

Reduced resource usage.

k3d and others are pretty good for running a K8s cluster.
However, I often find these local k8s emulators are using up my battery life much faster.

Additionally, if one is not operating on Linux, using containers is much less convenient, requiring a VM with memory commitment.

## Requirements

* go
* make
* cfssl
* some unix tools required to build kube-apiserver

Kubernetes only distributes binaries for kube-apiserver for linux, so the script will git clone and build from source for other platforms.

All the needed tools to install will be shown as errors and can be installed with brew on Mac.

## About

This is just some automatic setup that uses the [kubebrain](https://github.com/kubewharf/kubebrain) project. Certs are generated as outlined in [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md).

There is a similar existing project to kubebrain called [kine](https://github.com/k3s-io/kine). However, it seems to require installing a DB such as SQLite whereas kubebrain stores directly with the badger library.
