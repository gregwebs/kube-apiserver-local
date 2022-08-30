#!/usr/bin/env bash
set -euo pipefail

if ! curl -s 127.0.0.1:2379 | grep 404 ; then
	if ! [[ -d kubebrain ]] ; then
		git clone https://github.com/kubewharf/kubebrain
	fi
	pushd kubebrain
	if ! [[ -f ./bin/kube-brain ]] ; then
		make badger
	fi
	popd
fi

if ! [[ -f ca.pem ]] ; then
	cfssl gencert -initca ./csr/ca-csr.json | cfssljson -bare ca
fi

if ! [[ -f admin-key.pem ]] ; then
	cfssl gencert \
	  -ca=ca.pem \
	  -ca-key=ca-key.pem \
	  -config=ca-config.json \
	  -profile=kubernetes \
	  ./csr/admin-csr.json | cfssljson -bare admin
fi

if ! [[ -f service-account-key.pem ]] ; then
	cfssl gencert \
	  -ca=ca.pem \
	  -ca-key=ca-key.pem \
	  -config=ca-config.json \
	  -profile=kubernetes \
	  ./csr/service-account-csr.json | cfssljson -bare service-account
fi

sa_key=service-account-key.pem
sa=service-account.pem

K8S_VERSION=v1.25.0
apiserver=kube-apiserver
if ! command -v $apiserver ; then
	os="$(uname | tr '[:upper:]' '[:lower:]')"
	arch="$(uname -m)"
	if [[ "$os" == linux ]] ; then
		apiserver=./kube-apiserver
	else
		apiserver=./kubernetes/_output/local/bin/$os/$arch/kube-apiserver
	fi

	if ! [[ -f $apiserver ]] ; then
		if [[ "$arch" == linux ]] ; then
			echo "downloading kube-apiserver"
			wget https://dl.k8s.io/v1.25.0/bin/$os/$arch/kube-apiserver
			chmod +x kube-apiserver
		else
			echo "compiling kube-apiserver from source"
			if ! [[ -d kubernetes ]] ; then
			  git clone https://github.com/kubernetes/kubernetes
			  pushd kubernetes
			  git checkout $K8s_VERSION
			  popd
			fi
			pushd kubernetes
			make
			popd
		fi
	fi
fi

if ! [[ -f kubernetes-csr-key.pem ]] ; then
	cfssl gencert \
	  -ca=ca.pem \
	  -ca-key=ca-key.pem \
	  -config=ca-config.json \
	  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,127.0.0.1 \
	  -profile=kubernetes \
	  ./csr/kubernetes-csr.json | cfssljson -bare kubernetes
fi

pushd kubebrain
echo "launching kube-brain for data storage"
./bin/kube-brain &
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT
popd

$apiserver --storage-backend=etcd3 --etcd-servers=http://127.0.0.1:2379 \
	--allow-privileged=true \
	--authorization-mode=Node,RBAC \
	--bind-address=0.0.0.0 \
	--client-ca-file=ca.pem \
	--service-cluster-ip-range=127.0.0.0/16 \
	--api-audiences api \
	--service-account-issuer=api --service-account-signing-key-file=$sa_key --service-account-key-file=$sa \
	--tls-cert-file=kubernetes.pem --tls-private-key-file=kubernetes-key.pem \
	"$@"
