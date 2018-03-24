# Production Instance

A different name prefix and labels.

Deployment patched to increase the replica count.


<!-- @makeProductionManifest @test -->
```
cd /tmp/hello/instances
cat <<'EOF' >production/Kube-manifest.yaml
apiVersion: manifest.k8s.io/v1alpha1
kind: Package
metadata:
  name: makes-production-tuthello
description: Tuthello configured for production

namePrefix: production-

objectLabels:
  instance: production
  org: acmeCorporation

objectAnnotations:
  note: Hello, I am production!

packages:
- ../../base

patches:
- deployment.yaml

EOF
```

<!-- @productionDeployment @test -->
```
cd /tmp/hello/instances
cat <<EOF >production/deployment.yaml
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: the-deployment
spec:
  replicas: 6
EOF
```

