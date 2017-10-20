# Prototype of [Declarative Application Management](https://goo.gl/T66ZcD)

This demo assumes

 * Go 1.9.1 installed
 * git installed
 * Clone of k8s core at `$GOPATH/src/k8s.io/kubernetes`

The prototype used here is temporarily being developed
in a branch of _k8s.io/kubernetes_.

Concurrent to development of the prototype,
we're making a home for it in the _k8s.io/kubectl_
repo so others can work on it.  This is trickier
than it sounds because of code coupling issues.

In the meantime, we can demo from the core.

### Make a place to work

```
TUT_DIR=$(mktemp -d)
```

### Build your cloud

Get gcloud:
```
tmp=$HOME/google-cloud-sdk
if [ -d "$tmp" ]; then
  source $tmp/path.bash.inc
  source $tmp/completion.bash.inc
else
  echo Grab gcloud from https://cloud.google.com/sdk/downloads
fi
unset tmp

# Make sure you have it.
which gcloud

# Ignore this as we'll make our own kubectl below.
which kubectl
```

Configure it:
```
# Pick one of your existing projects.
TUT_PROJECT_ID=lyrical-gantry-618

# Define a new name.
TUT_CLUSTER_NAME=cluster-spinach

gcloud config set account jeff.regan@gmail.com
gcloud config set project $TUT_PROJECT_ID
gcloud config set compute/region us-west1
gcloud config set compute/zone us-west1-a
gcloud auth application-default login
gcloud config list
```

Make the cluster:
```
gcloud container clusters list
gcloud container clusters create $TUT_CLUSTER_NAME

# Done below
# kubectl get nodes
# kubectl get pods # None
```


### Grab code

```
cd $GOPATH/src/k8s.io/kubernetes

# Provides a reminder to commit/stash if needed.
git checkout master

REMOTE_NAME=kinflate
BRANCH_NAME=feature-apply-manifest

# Add a remote.
git remote add -t $BRANCH_NAME \
    $REMOTE_NAME https://github.com/monopole/kubernetes.git

# Fetch it.
git fetch $REMOTE_NAME

# Checkout the branch.
git checkout $REMOTE_NAME/$BRANCH_NAME
```


Spot check that you have the right code:
```
cd $GOPATH/src/k8s.io/kubernetes
# This should exist:
file ./pkg/kubectl/cmd/manifest/BUILD
```

Build it.
```
cd $GOPATH/src/k8s.io/kubernetes
go build -o $TUT_DIR/mykubectl k8s.io/kubernetes/cmd/kubectl
alias mykubectl=$TUT_DIR/mykubectl
mykubectl help kinflate
```

### Or just grab this linux-amd64 binary:

TODO: put a binary somewhere

### Define a manifest (multiple files)

```
mkdir -p $TUT_DIR/manifest
mkdir -p $TUT_DIR/instance/test
mkdir -p $TUT_DIR/instance/dev
mkdir -p $TUT_DIR/instance/prod
```

Define a manifest - metadata about an application:

```
cat <<'EOF' >$TUT_DIR/manifest/Kube-manifest.yaml
# Example from https://goo.gl/T66ZcD
# Inspired by https://github.com/kubernetes/helm/blob/master/docs/charts.md
# But Kubernetes API style
apiVersion: manifest.k8s.io/v1alpha1
kind: Package
metadata:
  name: mungebot
description: Mungegithub package
keywords: [github, bot, kubernetes]
appVersion: 0.1.0
home: https://github.com/bgrant0607/mungebot-pkg/blob/master/README.md
sources:
- https://github.com/bgrant0607/mungebot-pkg
icon: https://github.com/bgrant0607/mungebot-pkg/blob/master/icon.png

maintainers:
- name: Brian Grant
  email: briangrant@google.com
  github: bgrant0607

bases:
- deployment.yaml
#- service.yaml
#- pvc.yaml

# Recursive would be similar to kubectl --recursive behavior,
# extended to look for Kube-manifest.yaml
# recursive: false
EOF
```

Define an associated but generic deployment:
```
cat <<'EOF' >$TUT_DIR/manifest/deployment.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: mungebot
  labels:
    app: mungebot
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: mungebot
    spec:
      containers:
      - name: nginx
        image: nginx
        env:
        - name: foo
          value: bar
        ports:
        - containerPort: 80
EOF
```

Define an "instance" (aka overlay):
```
cat <<'EOF' >$TUT_DIR/instance/test/Kube-manifest.yaml
apiVersion: manifest.k8s.io/v1alpha1
kind: Package
metadata:
  name: test-infra-mungebot
description: Mungebot config for test-infra repo
namePrefix: test-infra-

# Labels to add to all objects and selectors.
# These labels would also be used to form the selector for apply --prune
# Named differently than “labels” to avoid confusion with metadata for this object
objectLabels:
  app: mungebot
  org: kubernetes
  repo: test-infra

objectAnnotations:
  note: This is my first try

# Note the relative path
bases:
- ../../manifest

# These are strategic merge patch overlays in the form of API resources
overlays:
- deployment.yaml

# There could also be configmaps in Base, which would make these overlays
configmaps:
- type: env
  namePrefix: app-env
  file: app.env
- type: file
  namePrefix: app-config
  file: app-init.ini

# There could be secrets in Base, if just using a fork/rebase workflow
secrets:
- type: tls
  namePrefix: app-tls
  certFile: tls.cert
  keyFile: tls.key
recursive: false
prune: true
EOF
```

Define an instance (overlay) deployment (gets merged with the base):
```
cat <<'EOF' >$TUT_DIR/instance/test/deployment.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: mungebot
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:1.7.9
      - name: busybox
        image: busybox
EOF
```


### Try it

```
mykubectl kinflate --alsologtostderr -v=5 \
    -f $TUT_DIR/instance/test > $TUT_DIR/result.yaml
```

# Compare output to input:
```
more $TUT_DIR/result.yaml
```

```
more $TUT_DIR/manifest/deployment.yaml
```



### Cleanup

```
git branch -D $REMOTE_NAME/$BRANCH_NAME
git remote rm $REMOTE_NAME
```

