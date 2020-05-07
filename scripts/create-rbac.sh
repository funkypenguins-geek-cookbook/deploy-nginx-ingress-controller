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

if [[ ! $service =~ ^[-a-z]{3,30}$ ]]
then
  usage "Service ${service} invalid. Username can only be lower-case letters, 3-30 characters in length"
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
  name: helm-deploy-${service}
  namespace: ${service}
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: helm-deploy-${service}
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
  name: helm-deploy-${service}
  namespace: ${service}
subjects:
- kind: ServiceAccount
  name: helm-deploy-${service}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: helm-deploy-${service}
---
# Note - this is not great, since it allows the holder of the role to technically assign themselves
# more clusterroles, but it's necessary to allow helm charts to create RBAC entries.
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: helm-deploy-${service}
rules:
  - apiGroups: ["", "rbac.authorization.k8s.io"]
    resources: ["clusterroles","clusterrolebindings"]
    verbs: ["*"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: helm-deploy-${service}
roleRef:
  kind: ClusterRole
  apiGroup: rbac.authorization.k8s.io
  name: helm-deploy-${service}
subjects:
  - kind: ServiceAccount
    name: helm-deploy-${service}
    namespace: ${service}
EOF

# Create the kubeconfig

echo -e "\n\nHere's the kubeconfig for the service account we just created:\n\n"
scripts/create-kubeconfig.sh ${service} --namespace ${service}