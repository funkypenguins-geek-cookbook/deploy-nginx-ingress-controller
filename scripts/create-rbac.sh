#!/bin/bash

service=$1

usage () {
  local errorMessage=$1
  echo
  echo "---------------------------------------------------------------"
  echo "Error: $errorMessage"
  echo "---------------------------------------------------------------"
  echo "usage: ./create-rbac.sh <username>"
  echo "  e.g. ./create-rbac.sh batman"
  echo "---------------------------------------------------------------"
  exit 1
}

if [ -z "$service" ]
then
  usage "No service specified"
fi

if [[ ! $service =~ ^[-a-z]{3,20}$ ]]
then
  usage "Service ${service} invalid. Username can only be lower-case letters, 3-20 characters in length"
fi

echo "Creating namespace and RBAC config for ${service}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ${service}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sa-${service}
  namespace: ${service}
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: role-${service}
  namespace: ${service}
rules:
- apiGroups: ["", "extensions", "apps", "rbac.authorization.k8s.io", "apiextensions.k8s.io", "networking.k8s.io" ]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["batch"]
  resources:
  - jobs
  - cronjobs
  verbs: ["*"]

---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: rb-${service}
  namespace: ${service}
subjects:
- kind: ServiceAccount
  name: sa-${service}
  namespace: ${service}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: role-${service}
EOF

# Create the kubeconfig

scripts/create-kubeconfig.sh ${service} --namespace ${service}
