# Staging Manifest

In the `staging` directory, make a manifest
defining a new name prefix, and some different labels.

<!-- @makeStagingManifest @test -->
```
cat <<'EOF' >$OVERLAYS/staging/Kube-manifest.yaml
apiVersion: manifest.k8s.io/v1alpha1
kind: Package
metadata:
  name: makes-staging-hello

description: hello configured for staging

namePrefix: staging-

objectLabels:
  instance: staging
  org: acmeCorporation

objectAnnotations:
  note: Hello, I am staging!

packages:
- ../../base

patches:
- map.yaml

EOF
```

Add a configmap customization to change the
server greeting from _Good Morning!_ to _Have a
pineapple!_.

Also, enable the _risky_ flag.

<!-- @stagingMap @test -->
```
cd /tmp/hello/instances
cat <<EOF >staging/map.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: the-map
data:
  altGreeting: "Have a pineapple!"
  enableRisky: "true"
EOF
```
