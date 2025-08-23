#!/bin/bash

# Create service account and token for Chaos Mesh dashboard
kubectl create serviceaccount chaos-dashboard-viewer -n chaos-mesh
kubectl create clusterrolebinding chaos-dashboard-viewer --clusterrole=cluster-admin --serviceaccount=chaos-mesh:chaos-dashboard-viewer

# Create token secret
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: chaos-dashboard-viewer-token
  namespace: chaos-mesh
  annotations:
    kubernetes.io/service-account.name: chaos-dashboard-viewer
type: kubernetes.io/service-account-token
EOF

echo "Getting token for dashboard access..."
kubectl get secret chaos-dashboard-viewer-token -n chaos-mesh -o jsonpath='{.data.token}' | base64 -d
echo ""