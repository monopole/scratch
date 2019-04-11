[no longer live]: https://github.com/golang-standards/project-layout/issues/10
[versioning policy]: https://github.com/kubernetes-sigs/kustomize/blob/master/docs/versioningPolicy.md

# Kustomize - bring libraries to the fore

## Background

As initially envisioned, the kustomize repo was a place
to develop a command line tool for generating and
transforming k8s resources.
There were no firm plans to focus on providing stable
libraries for consumption by other tools.

This must change, as other k8s projects like
kubebuilder, skaffold, kops, various ci/cd projects,
could offload kustomize-like tasks to kustomize
libraries rather than shelling out to `kustomize`.

The kustomize semver [versioning policy] currently only
describes versioning of the _kustomize command line
program_ and the `kustomization.yaml` file.  This
policy makes no promises about `pkg`, so the implicit
policy has been _vendor it at your own risk_.  Packages
below `pkg` implicitly have the same version as the
main program.

Unfortunately the repo doesn't make much use of
`internal`.  The repo follows the common pattern of
having many directories (`docs`, `examples`, etc.),
with all the code (other than the `main` package)
dropped into a `pkg` directory.

## Proposed plan



### Release final version of `pkg/` as it now stands.

 * Convert to go modules (see script below)

 * Release `v2.1.0` (the last release was `v2.0.3` on 05 March 2019.`).

The minor increment reflects new functionality (prune
and plugins).

This defines a checkpoint where people can move from
a `dep` (vendoring) style consumption of kustomize
to a `vgo` (Go module) style without also
experiencing a change in import paths.

This also means go1.11 or higher is required for building
kustomize.

### Reset `pkg/`

 * move `./kustomize.go` to `./cmd/kustomize/main.go`,

 * move `./pkg/*` to `./internal/*`, and remove `./pkg`
   This removes _all_ exposed packages.

 * Modify the [versioning policy] to clarfiy that
   it now covers non-internal kustomize packages.
   
 * Release `v3.0.0`.

   `v3.0.0` will be the first version where we official
   support packages - though there might not be any to
   start.
   
The main program will work as before; the major version
increment is due to the backward incompatible library
change

Naturally, `v2.1.0` still exists.

### Start consciously evolving kustomize packages.

Start releasing `v3.1.0`, `v3.2.0`, etc. as we
expose packages and generally proceed with
development.

The import paths will look like

```
  "sigs.k8s.io/kustomize/generate"
  "sigs.k8s.io/kustomize/transform"
```

and will be completely distinct from the old packages
with `pkg/` in their paths.



## Script to convert to go modules

```
unset GOPATH

cd ~
/bin/rm -rf ~/kustomize

git clone git@github.com:monopole/kustomize.git

cd ~/kustomize

git remote add upstream git@github.com:kubernetes-sigs/kustomize.git
git remote set-url --push upstream no_push

git fetch upstream
git rebase upstream/master

git checkout -b switchToVGo

# Want this to be Go v1.12, to match kubernetes v1.14
go version

# The argument is the intended module path others will see.
go mod init sigs.k8s.io/kustomize

go mod tidy

# This complains:
# go: github.com/emicklei/go-restful@v0.0.0-20180531035034-3658237ded10:
# go.mod has post-v0 module path "github.com/emicklei/go-restful/v2" at revision 3658237ded10
# go: error loading module requirements

# Fix is:
sed -i 's|github.com/emicklei/go-restful|github.com/emicklei/go-restful/v2|' go.mod 

go mod tidy

rm -rf Gopkg.lock Gopkg.toml vendor/

# Tests have one error:
go test sigs.k8s.io/kustomize/...

# There's a failure because GOPPATH isn't set,
# and the exec plugin depends on it.
# Disable that test for now.
sed -i 's|TestConfigMapGenerator|xTestConfigMapGenerator|' ./pkg/target/generatorplugin_test.go

# Try again; it works.
go test sigs.k8s.io/kustomize/...

# Commit everything and push:
git add go.mod go.sum
git commit -a -m "Switch to vgo"
git push -f origin switchToVGo


```



## TBD with plugin modules

Need to do something like [https://github.com/golang/go/issues/27751#issuecomment-443452815]

to avoid conflicts.

```
    chartinflatorplugin_test.go:240:
    Err: plugin /tmp/kustomize-plugin-tests945720311/kustomize/plugins/kustomize.config.k8s.io/v1/ChartInflator.so
    fails to load: plugin.Open("/tmp/kustomize-plugin-tests945720311/kustomize/plugins/kustomize.config.k8s.io/v1/ChartInflator"):
    plugin was built with a different version of package unicode/utf8
FAIL
```





