# Kustomize - bring libraries to the fore

## Background

As initially envisioned, the kustomize repo was a place
to develop a command line tool for generating and
transforming k8s resources.

There were no firm plans to focus on providing stable
_libraries_ for consumption by other tools.  But other
kubernetes development and ci/cd tools like
kubebuilder, skaffold, kops, etc., started using the
libraries.

The kustomize semver [versioning policy] currently only
describes versioning of the _main program_ and the
`kustomization.yaml` file.

It doesn't make any promises about `pkg`, so our
implicit policy has been _vendor at your own risk_, and
the `pkg` libraries have the same version as the main
program.

Unfortunately the repo doesn't make much use of
`internal`.  The repo follows the common pattern of
having many directories (`docs`, `examples`, etc.),
with all the code (other than the main package) dropped
into a `pkg` directory.

## Proposed plan

The last release was _v2.0.3_ on 05 March 2019.

There have been changes in functionality, but these
changes are behind command line flags or behind new
commands.

Steps:

 * With the repo as is, we:

   * Initialize a top level `./go.mod`, with module name
     `sigs.k8s.io/kustomize`.

   * `rm -rf Gopkg.* ./vendor`

   * Release _v2.1.0_ (previous was _v2.0.3_)

   The minor increment reflects new functionality (prune
   and plugins).

   This defines a checkpoint where people can move from
   a `dep` (vendoring) style consumption of kustomize
   to a `vgo` (Go module) style without also
   experiencing a change in import paths.

   This also means go1.11 or higher is required for building
   kustomize.

 * Then we:

   * move `./kustomize.go` to `./cmd/kustomize/main.go`,

   * move `./pkg/*` to `./internal/*`, and remove `./pkg`

     This removes _all_ exposed packages.

   * Release v3.0.0.

     v3.0.0 will be the first version where we official
     support packages - though there might not be any
     to start.  The main program will work as before;
     the major version increment is due to the backward
     incompatible library change

     Naturally, v2.1.0 still exists.

 * Next start releasing v3.1.0, v3.2.0, etc. as we
   expose packages and generally proceed with
   development.

   The import paths will look like

   > ```
   >   "sigs.k8s.io/kustomize/generate"
   >   "sigs.k8s.io/kustomize/transform"
   > ```

   and will be completely distinct from the old packages with `pkg/`
   in their paths.

[no longer live]: https://github.com/golang-standards/project-layout/issues/10
[versioning]: https://github.com/kubernetes-sigs/kustomize/blob/master/docs/versioningPolicy.md


## TBD

 *  arrange plugins into submodules with known deps that don't
    conflict with kustomize main.

```
    chartinflatorplugin_test.go:240:
    Err: plugin /tmp/kustomize-plugin-tests945720311/kustomize/plugins/kustomize.config.k8s.io/v1/ChartInflator.so
    fails to load: plugin.Open("/tmp/kustomize-plugin-tests945720311/kustomize/plugins/kustomize.config.k8s.io/v1/ChartInflator"):
    plugin was built with a different version of package unicode/utf8
FAIL
```
Debugger finished with exit code 0



## Script for converting

```
unset GOPATH

cd ~
/bin/rm -rf ~/kustomize

git clone git@github.com:monopole/kustomize.git




cd ~/kustomize

git remote add upstream git@github.com:sigs.k8s.io/kustomize.git
git remote set-url --push upstream no_push

git fetch upstream
git rebase upstream/master

# Verify on branch master, nothing changed or staged.
git status

git checkout -b switchToVGo

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

# test without error
go test sigs.k8s.io/kustomize/...

sed -i 's|TestConfigMapGenerator|xTestConfigMapGenerator|' ./pkg/target/generatorplugin_test.go

# The dependencies
git add go.mod

# crypto hash of the packages to double check
git add go.sum

git commit -a -m "Switch to vgo"
git push -f origin switchToVGo


```



