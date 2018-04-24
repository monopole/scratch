# Prototype of [Declarative Application Management](https://goo.gl/T66ZcD)

This tutorial assumes

 * git installed
 * Go 1.9.1 installed
 * You have a [gcloud](https://cloud.google.com) account,
   or can adapt what follows to some other cluster host.

The prototype used here is temporarily being developed
in a branch of _k8s.io/kubernetes_.

Concurrent to development of the prototype,
we're making a home for it in the _k8s.io/kubectl_
repo so others can work on it.  This is trickier
than it sounds because of code coupling issues
in the core.

## Customize your environment

__ATTENTION__:
This is the only thing that _requires_ an edit to work.

Run it, but then up-arrow/edit/enter to customize.

```
# Specify your actual account.
TUT_ACCOUNT_ID=some.person@gmail.com

# Specify an actual project associated with that account.
TUT_PROJECT_ID=lyrical-gantry-618
```


## Make a place to work

<!-- @mkTmpDir @demo -->
```
TUT_DIR=$(mktemp -d)
```

## Configure gcloud

<!-- @getGcloud @demo -->
```
tmp=$HOME/google-cloud-sdk
if [ -d "$tmp" ]; then
  source $tmp/path.bash.inc
  source $tmp/completion.bash.inc
else
  echo Grab gcloud from https://cloud.google.com/sdk/downloads
fi
unset tmp
```

<!-- @confirmGcloud @demo -->
```
which gcloud
```

<!-- @logIn @demo -->
```
gcloud config set account $TUT_ACCOUNT_ID
gcloud auth application-default login
```

<!-- @setMiscState @demo -->
```
gcloud config set project $TUT_PROJECT_ID
gcloud config set compute/region us-west1
gcloud config set compute/zone us-west1-a
```

### Make a cluster if necessary

<!-- @listClusters @demo -->
```
gcloud config list
gcloud container clusters list
```

If you don't have one, make one:
<!-- @makeACluster @demo -->
```
gcloud container clusters create cluster-kinflate-demo
```

You should now have at least one cluster:
<!-- @confirmNewCluster @demo -->
```
gcloud container clusters list
```

## Pull and build the prototype...

<!-- @makeDisposableDirectory @demo -->
```
GIT_DIR=$TUT_DIR/src/k8s.io/kubernetes
mkdir -p $GIT_DIR
```

<!-- @initDisposableRepo @demo -->
```
cd $GIT_DIR
git init
```

<!-- @addRemote @demo -->
```
cd $GIT_DIR
REMOTE_NAME=kinflate
BRANCH_NAME=feature-apply-manifest

git remote add -t $BRANCH_NAME \
    $REMOTE_NAME https://github.com/monopole/kubernetes.git
```

Enter this, then catch up on [hacker news](https://news.ycombinator.com).
<!-- @fetchCode @demo -->
```
cd $GIT_DIR
git fetch $REMOTE_NAME
git checkout $REMOTE_NAME/$BRANCH_NAME
```

Optional (if some changes were committed during
the life of this temp repo):
```
cd $GIT_DIR
git fetch $REMOTE_NAME
git merge $REMOTE_NAME/$BRANCH_NAME -X theirs -m whatever
```

Spot check a file to confirm the branch:
<!-- @spotCheck @demo -->
```
file $GIT_DIR/pkg/kubectl/cmd/manifest/BUILD
```

<!-- @build @demo -->
```
GOPATH=$TUT_DIR go build -o $TUT_DIR/mykubectl \
    k8s.io/kubernetes/cmd/kubectl
alias mykubectl=$TUT_DIR/mykubectl
```

## ...Or just grab this linux-amd64 binary:

TODO: put a `mykubectl` binary snapshot somewhere

## Do the demo

Does the `kinflate` command exist?
If so, you're ready to go.

<!-- @checkHelpMessage @demo -->
```
mykubectl help kinflate
```

### Define a manifest tree

<!-- @makeTree @demo -->
```
mkdir -p $TUT_DIR/manifest
mkdir -p $TUT_DIR/instance/test
mkdir -p $TUT_DIR/instance/dev
mkdir -p $TUT_DIR/instance/prod
```

Define a manifest - metadata about an application:

<!-- @makeResourceManifest @demo -->
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

resources:
- deployment.yaml
#- service.yaml
#- pvc.yaml

# Recursive would be similar to kubectl --recursive behavior,
# extended to look for Kube-manifest.yaml
# recursive: false
EOF
```

Define an associated but generic deployment:
<!-- @makeDeployment @demo -->
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

Define a patch - a customization of base resources:
<!-- @makePatchManifest @demo -->
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
resources:
- ../../manifest

# Strategic merge patches in the form of API resources
patches:
- deployment.yaml

# There could also be configmaps in resources,
# which would make these patches:
configmaps:
- type: env
  namePrefix: app-env
  file: app.env
- type: file
  namePrefix: app-config
  file: app-init.ini

# There could be secrets in resources, if just using a fork/rebase workflow
secrets:
- type: tls
  namePrefix: app-tls
  certFile: tls.cert
  keyFile: tls.key
recursive: false
prune: true
EOF
```

Define a patch, creating a specific instance to merge with base resources.
<!-- @makePatchedDeployment @demo -->
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
<!-- @runKinflate @demo -->
```
mykubectl kinflate --alsologtostderr -v=5 \
    -f $TUT_DIR/instance/test > $TUT_DIR/result.yaml
```

If the above command fails with a `certificate signed by unknown
authority` error, then clearly _you are holding it wrong and you
should feel bad about yourself._

Revoke your login, re-login, and create a new cluster, then try again
(seriously, that should work).

<!-- @reviewNewDeployment @demo -->
```
more $TUT_DIR/result.yaml
```

<!-- @reviewOriginalDeployment @demo -->
```
more $TUT_DIR/manifest/deployment.yaml
```

### Cleanup

Or just let the system wipe it someday, since its in /tmp.
<!-- @optionalCleanup @demo -->
```
/bin/rm -rf $TUT_DIR
cd
```
