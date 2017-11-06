# Proposal: Move `resource` and `validation` code to k8s.io/common

### Abstract

This doc describes a strategy to move some `kubectl`
code out of the kubernetes core and into a repo
intended for vendoring, in support the general goal of
[extracting kubectl from the core repo][598].  The
strategy allows the moved code to be used immediately,
even before the packages involved are fully extracted
from the core.

The moved code allows a wider range of people to work
on a [DAM] prototype called `kexpand`.  This program,
like `kubectl`, should not live in the core, but will
share code with the core.

### Background

`kubectl` currently lives in the _k8s.io/kubernetes_
repo, also known as the _core_ repo.  Packages in this
repo are not intended for vendoring.  On the other
hand, packages in [_k8s.io/client-go_] and (to some
extent) [_k8s.io/apimachinery_] are intended for
vendoring.

It's generally agreed that `kubectl`, a program that's
supposed to be a pure API client with no dependencies
on core code, should move out of _k8s.io/kubernetes_
and into _k8s.io/kubectl_, hence the name of the latter
repo.  Likewise, no new command line API clients should
appear in core.

Such a move requires additional repos like
_k8s.io/common_ and _k8s.io/utils_, to hold code shared
by `kubectl`, `kubernetes`, and other projects.

[DAM]: https://goo.gl/T66ZcD

Against this backdrop, we want to write a
[DAM]-enabling prototype called [`kexpand`] that wants
to use the shared code.  This should be done in a way
that improves, rather than worsens, relations between
these repositories:

* [_k8s.io/kubernetes_] -- core kubernetes components;
  kubelet, scheduler, etc.
* [_k8s.io/kubectl_] -- home of `kexpand`
  and eventual home of `kubectl`.
* [_k8s.io/common_] -- code shared by `kexpand`,
  `kubectl` and the core.
* [_k8s.io/utils_] -- code shared by everyone (a supplement to [golang]).

[`kexpand`]: https://github.com/kubernetes/kubectl/tree/master/cmd/kexpand

[_k8s.io/kubernetes_]: https://github.com/kubernetes/kubernetes
[_k8s.io/kubectl_]: https://github.com/kubernetes/kubectl
[_k8s.io/common_]: https://github.com/kubernetes/common
[_k8s.io/utils_]: https://github.com/kubernetes/utils
[_k8s.io/apimachinery_]: https://github.com/kubernetes/apimachinery
[_k8s.io/client-go_]: https://github.com/kubernetes/client-go
[golang]: https://golang.org/pkg/
[_k8s.io/kubernetes/pkg/kubectl_]: https://github.com/kubernetes/kubernetes/tree/master/pkg/kubectl

`kexpand` needs to re-use code currently used by
`kubectl` that lives in
[_k8s.io/kubernetes/pkg/kubectl_] - at least the
`resource` and `validation` packages (see
Appendix).

To allow reuse, these packages should move to
_k8s.io/common_.

[50475]: https://github.com/kubernetes/kubernetes/issues/50475
[598]: https://github.com/kubernetes/community/pull/598

Moving code requires

1. Copying code, retaining git history.
1. Arranging for the code to get the
   deps it needs in its new location.
1. Repairing things in the original location
   by vendoring from the new location.
1. Deleting the now unreferenced code
   from the original location.

This is part of a larger problem of factoring
_k8s.io/kubernetes_ into smaller reusable parts.  We
want to start working on `kexpand` before everything is
detangled, but do so in a way that helps improve the
overall situation rather than making it worse.

Rejected schemes include building `kexpand` in the core
repo (introducing yet another eventual extraction
problem), and building `kexpand` by vendoring in _all_
of _k8s.io/kubernetes_, solving problems that creates,
while doing nothing towards moving code out of core
into to repos meant for vendoring.

### Work

The Appendix below has a
script that locally copies code from
_k8s.io/kubernetes_
<blockquote>
<pre>
{project}/      {repo}/   {path}
   k8s.io/  kubernetes/   pkg/api
   k8s.io/  kubernetes/   pkg/kubectl/resource
   k8s.io/  kubernetes/   pkg/kubectl/validation
</pre>
</blockquote>

to these respective directories in _k8s.io/common_:

<blockquote>
<pre>
   k8s.io/      common/   pkg/api
   k8s.io/      common/   resource
   k8s.io/      common/   validation
</pre>
</blockquote>

This informs and emulates the desired end state of
`resource` and `validation` living in
_k8s.io/common_.

Nobody wants `pkg/api` to live there too, since it
holds unversioned types that are not part of a public
API.  Unfortunately, `resource` and `validation` depend
on it at the moment.  Breaking this dependence is part
of work described below.

Two projects can now proceed independently:

#### Project 1) Permanently extract code from core to _k8s.io/common_

 * Add a warning to _k8s.io/common/README.md_
   explaining that the repo is merely a mirror and
   should not accept changes (as is done for
   [_k8s.io/apimachinery_]).

 * Within _k8s.io/kubernetes_, break `resource` and
   `validation`'s dependence on core packages like
   `pkg/api`.  This is the tricky part.

 * Per work in project 2, `resource` and `validation`
   are periodically copied to _k8s.io/common_
   preserving git history.

 * Modify all code in _k8s.io/kubernetes_ (in
   particular the `kubectl` program) to vendor
   `resource` and `validation` from _k8s.io/common_
   instead, and delete `resource` and `validation` from
   _k8s.io/kubernetes_.  Commit the change.

 * Remove the warning in _k8s.io/common/README.md_; the
   repo now a normal repository containing the
   canonical `resource` and `validation` source code.

#### Project 2) Establish development loop for `kexpand`

 * Come to work in the morning.

 * Optionally refresh `resource` and `validation`.

   * For a time (until project 1 completes) treat
     _k8s.io/common_ as a generated, non-canonical
     repo.  Its `README` should label the repo as a
     generated copy of certain directories from
     _k8s.io/kubernetes_.

   * Use the script below to copy `resource`,
     `validation`, etc. from an up-to-date local clone
     of _k8s.io/kubernetes_ to a local clone of
     _k8s.io/common_, preserving history and adapting
     the code as needed (e.g. package path changes).

   * Diff local _k8s.io/common_ against upstream
     github, and if it has sufficiently changed, push
     it upstream into github.

   * cd into _k8s.io/kubectl_ and run the [`dep`] tool
     to freshly vendor from (github) _k8s.io/common_
     into (local) _k8s.io/kubectl/vendor_.

   * Push _k8s.io/kubectl/vendor_ changes upstream to
     github.

 * Make improvements to `kexpand` in
   _k8s.io/kubectl_.

 * Push `kexpand` changes upstream.

[`dep`]: https://github.com/golang/dep

The result is that `kexpand` will be built to vendor
from _k8s.io/common_ which is the desired _final_
state, but without first requiring the work necessary
to turn _k8s.io/common_ into a "normal" repo

## Appendix

### Investigation - what core code is needed?

Define some bazel query functions:

```
# Show all dependencies of $1
function whatDoesThisNeed {
  local path=$1
  local target=$path
  if [[ $target != *":"* ]]; then
    target="$target:go_default_library"
  fi
  pushd $GOPATH/src/k8s.io/kubernetes >/dev/null
  bazel query "buildfiles(deps($target))" |\
    grep -v @bazel_tools |\
    grep -v @io_bazel_rules |\
    grep -v @io_kubernetes_build |\
    grep -v @go1_8_3 |\
    grep -v @local_config |\
    grep -v @local_jdk |\
    grep -v build/visible_to: |\
    grep -v //external: |\
    grep -v $path |\
    grep -v //vendor/ |\
    sed 's/:BUILD//' |\
    grep -v /.bazel |\
    sort | uniq
  popd >/dev/null
}

# Show _any_ path from $1 to $2
function whyThisDep {
  local myGuy=$1
  local theConfusingDep=$2
  if [[ $myGuy != *":"* ]]; then
    myGuy="$myGuy:go_default_library"
  fi
  pushd $GOPATH/src/k8s.io/kubernetes >/dev/null
  bazel query "somepath($myGuy, $theConfusingDep:*)"
  popd >/dev/null
}

# Show _all_ paths from $1 to $2
function showAllPaths {
  local myGuy=$1
  local theConfusingDep=$2
  pushd $GOPATH/src/k8s.io/kubernetes >/dev/null
  local q="allpaths($myGuy/...,$theConfusingDep:*)"
  echo $q
  bazel query $q
  bazel query $q --output graph | dot -Tpng > /tmp/dep.png
  echo " "
  echo "Try:"
  echo " display /tmp/dep.png"
  popd >/dev/null
}
```

####  Investigate

What does `validation` need?
```
whatDoesThisNeed //pkg/kubectl/validation
```
<blockquote>
<pre>
//tools/defaults
</pre>
</blockquote>

The `tools/defaults` target is internal to bazel:
```
whyThisDep pkg/kubectl/validation tools/defaults
```
so we don't need to worry about it.

What does `resources` need?
```
whatDoesThisNeed //pkg/kubectl/resource
```
<blockquote>
<pre>
//hack/boilerplate
//pkg/api
//pkg/kubectl/validation
//tools/defaults
</pre>
</blockquote>


Why `//hack/boilerplate`?
```
whyThisDep pkg/kubectl/resource hack/boilerplate
```

Digging in shows that apimachinery has a hack to copy
`/hack` from the main repo into their own repo to
satisfy this dep; we might do the same.

Why does `resource` depend on `validation`?

```
whyThisDep pkg/kubectl/resource pkg/kubectl/validation
```
Because it uses `schema.go`.

Why does `resource` depend on `pkg/api`?

```
whyThisDep pkg/kubectl/resource pkg/api
```
The output is just
<blockquote>
<pre>
//pkg/kubectl/resource:go_default_library
//pkg/api:go_default_library
//pkg/api:taint.go
</pre>
</blockquote>

Possibly we can delete _everything_ under api
except `taint.go` and whatever else it needs locally.

It's interesting to look at all paths from build
targets below `resource` to targets below `pkg/api`,
some of which go through `pkg/apis`.  The tests in
`resource` have many more dependencies than just
`resource`.

```
showAllPaths pkg/kubectl/resource pkg/api
```


### The morning refresh script

Define the github user that owns the cloud based forks
of _kubernetes_:

```
GH_USER_NAME=monopole
```

Clone the target repo.

This is where copied from core must land and be
massaged into a working state before being pushed to
github's _kubernetes/common_.  `kexpand` will then
vendor it from github via the `dep` tool.

This disposable working directory is created by a script.
```
TMP_GOPATH=$(mktemp -d)
WORK_TARGET=$TMP_GOPATH/src/k8s.io/common
mkdir -p $WORK_TARGET
git clone https://github.com/$GH_USER_NAME/common $WORK_TARGET
```

Create a branch to work in:
```
cd $WORK_TARGET
BRANCH_NAME=contentMove
git checkout -b $BRANCH_NAME
```

[gbayer]: http://gbayer.com/development/moving-files-from-one-git-repository-to-another-preserving-history

Define a function to copy a specific directory from
a source repo to a target repo.  The technique used
to [retain git history][gbayer] means only one
directory can be moved at a time:
```
function copyDirectory {
  local DIR_SOURCE=$1
  local DIR_TARGET=$2
  local REMOTE_NAME=whatever

  # Place to clone it.
  local WORK_SOURCE=$(mktemp -d)

  git clone \
      https://github.com/$GH_USER_NAME/kubernetes \
      $WORK_SOURCE

  cd $WORK_SOURCE
  git checkout -b $BRANCH_NAME

  # Delete everything in the source repo
  # except the files to move:
  git filter-branch \
    --subdirectory-filter $DIR_SOURCE \
    -- --all

  # Show what's left
  ls

  # Move retained content to the target directory
  # in the target repo.
  mkdir -p $DIR_TARGET

  # The -k avoids the error from '*' picking
  # up the target directory itself.
  git mv -k * $DIR_TARGET

  # Commit the change locally.
  git commit -m "Isolated content of $DIR_SOURCE"

  # The repo now contains ONLY the code to copy.
  # Do the copy.
  cd $WORK_TARGET
  # echo Should be on branch $BRANCH_NAME
  git status

  git remote add $REMOTE_NAME $WORK_SOURCE
  git fetch $REMOTE_NAME
  git merge --allow-unrelated-histories \
      -m "Copying $DIR_SOURCE" \
      $REMOTE_NAME/$BRANCH_NAME
  git remote rm $REMOTE_NAME

  # Delete the traumatized `$WORK_SOURCE` directory.
  rm -rf $WORK_SOURCE

  # TODO: Use sed to adjust import statements.
}
```

Do the actual copy:

```
copyDirectory pkg/api                pkg/api
copyDirectory pkg/kubectl/validation validation
copyDirectory pkg/kubectl/resource   resource
copyDirectory hack/boilerplate       hack/boilerplate
```

This leaves `$WORK_TARGET`, which started as a clone of
_k8s.io/common_, with fresh copies of `pkg/api`, etc.


#### Adjust imports

We only want to import kubernetes code (`k8s.io/...`)
that is intended for vendoring.

Examine the current set of imports, ignoring
imports of things intended for vendoring:


```
function scanImports {
  find ./ -name "*.go" |\
    xargs grep "\"k8s.io/" |\
    grep -v "// import \"" |\
    sed 's|^\./\(.*\):.*\"\(.*\)\"|\2    \1|' |\
    sort |\
    uniq |\
    grep -v k8s.io/api/ |\
    grep -v k8s.io/apimachinery/ |\
    grep -v k8s.io/apiserver/ |\
    grep -v k8s.io/client-go/ |\
    grep -v k8s.io/common/ |\
    grep -v k8s.io/kube-openapi/ |\
    grep -v k8s.io/utils/
}
```

```
cd $WORK_TARGET
scanImports
```

##### Remove test stuff

The output has a bunch of test stuff.

This isn't the canonical repo, so rather than spend time
fixing the tests and test support code - delete it:
```
cd $WORK_TARGET
find ./ -name "*_test.go" | xargs rm
rm -rf pkg/api/testing
rm -rf pkg/api/testapi
```

### Adjust imports


Edit imports so that the moved code is
imported from _k8s.io/common_ instead of _k8s.io/kubernetes_:

```
function adjustImport {
  local file=$1
  local old=$2
  local new=$3
  local c="s|\\\"k8s.io/kubernetes/$old/|\\\"k8s.io/common/$new/|"
  sed -i $c $file
  local c="s|\\\"k8s.io/kubernetes/$old\\\"|\\\"k8s.io/common/$new\\\"|"
  sed -i $c $file
}
function adjustAllImports {
  for i in $(find . -name '*.go' );
  do
    adjustImport $i $1 $2
  done
}
```

```
adjustAllImports pkg/api                pkg/api
adjustAllImports pkg/kubectl/validation validation
adjustAllImports pkg/kubectl/resource   resource
adjustAllImports hack/boilerplate       hack/boilerplate
```

Rerun the import scan:

```
cd $WORK_TARGET
scanImports
```

There is still considerable dependence on non-vendored directories:


```
k8s.io/kubernetes/pkg/apis/extensions    pkg/api/v1/conversion.go
k8s.io/kubernetes/pkg/capabilities    pkg/api/validation/validation.go
k8s.io/kubernetes/pkg/features    pkg/api/pod/util.go
k8s.io/kubernetes/pkg/features    pkg/api/validation/validation.go
k8s.io/kubernetes/pkg/security/apparmor    pkg/api/validation/validation.go
k8s.io/kubernetes/pkg/util/hash    pkg/api/endpoints/util.go
k8s.io/kubernetes/pkg/util/hash    pkg/api/v1/endpoints/util.go
k8s.io/kubernetes/pkg/util/net/sets    pkg/api/service/util.go
k8s.io/kubernetes/pkg/util/net/sets    pkg/api/v1/service/util.go
k8s.io/kubernetes/pkg/util/parsers    pkg/api/v1/defaults.go
k8s.io/kubernetes/pkg/util/pointer    pkg/api/v1/defaults.go
```

E.g. `pkg/api/validation/validation.go` depends on
`pkg/security` which is not intended for vendoring, and
which we've not copied.

We could copy it, but that will simply bring in more
deps, leading to the same problem. We want to stop
somewhere or we'll be copying all of kubernetes into
common, which is nonsensical.

Another option is to not bother copying, and proceed
with `kexpand` development after vendoring _all of
kubernetes_ (rather than just `resource`, `validation`,
etc.) - but as discussed above that approach both
requires additional hacks and gets us no closer to
sharing code.

Recall from above that bazel claimed that `resource`
depended on `pkg/api` (`taint.go`) and said nothing
about a dependence on `pkg/security`.

Here are some confirmed dependences:
```
whyThisDep pkg/api/validation pkg/security/apparmor
whyThisDep pkg/kubectl/resource pkg/api
```

But the following dependency checks fail:
```
PACKAGES="
pkg/api/endpoints
pkg/api/pod
pkg/api/service
pkg/api/v1
pkg/api/v1/endpoints
pkg/api/v1/helper
pkg/api/v1/node
pkg/api/v1/pod
pkg/api/v1/resource
pkg/api/v1/service
pkg/api/v1/validation
pkg/api/validation
"

for i in $PACKAGES
do
  echo " "
  echo $i
  whyThisDep pkg/kubectl/resource $i
  whyThisDep pkg/kubectl/validation $i
done
```

That means we should be able to delete them (from the
copy), and thus not worry about their transitive
dependencies (`pkg/security/apparmor`, `pkg/features`,
`pkg/util/...`, etc.)


Try a build:
```
GOPATH=$TMP_GOPATH go build k8s.io/common/validation
```



##### Other problems

2) `k8s.io/kubernetes/pkg/apis/extensions    pkg/api/v1/conversion.go`

The conversion.go depends on `pkg/apis`,
which we're not copying, and don't
plan to vendor.  Does anything use it?

```
grep "func [A-Z]" pkg/api/v1/conversion.go

find ./ -name "*.go" |\
  grep -v pkg/api/v1/conversion.go |\
  grep -v zz_generated.conversion.go |\
  xargs grep Convert_

find ./ -name "*.go" |\
  grep -v pkg/api/v1/conversion.go |\
  grep -v zz_generated.conversion.go |\
  xargs grep AddFieldLabelConversionsFor
```

Nothing other than `./pkg/api/v1/zz_generated.conversion.go` uses it.
Does anything use that?




#### Nuke it from orbit

```
echo rm -rf $TMP_GOPATH
```



#### Reset workspace

Reset bazel workspace:
```
cd $WORK_TARGET
bazel clean --expunge

export WORKSPACE=$WORK_TARGET
rm $WORKSPACE/WORKSPACE
touch $WORKSPACE/WORKSPACE
cp $GOPATH/src/k8s.io/kubernetes/WORKSPACE $WORKSPACE
# Just in case
bazel clean --expunge

rm -rf $WORK_TARGET/__my_bazel
alias mybazel="bazel --output_user_root=$WORK_TARGET/__my_bazel "
```

Reset `dep` vendoring:
```
cd $WORK_TARGET
rm -rf vendor/ Gopkg.lock  Gopkg.toml
```

#### Building the copied code


Try this:
```
cd $WORK_TARGET
mybazel build hack/boilerplate:boilerplate.go.txt
```

If it fails, try this, and try again:
```
# see https://github.com/kubernetes/kubernetes/issues/52677
function fixBug52677 {
  local hash=$(ls -C1 /tmp/bazel | grep -v install)
  local fixMe=/tmp/bazel/$hash/external/io_bazel_rules_go/go/private/binary.bzl
  grep "\[lib\]" $fixMe
  sed -i 's/\[lib\]/\[libs\]/' $fixMe
  grep "\[libs\]" $fixMe
}
fixBug52677
```

and continue...
```
cd $WORK_TARGET
mybazel build validation:go_default_library
```

That doesn't work - try raw go:
```
GOPATH=$TMP_GOPATH go build k8s.io/common/validation
```
Depending on where you are in the timeline, you may get complaints about
missing packages that need to be vendored.

### Set up vendoring

```
GOPATH=$TMP_GOPATH
cd $WORK_TARGET
dep init
```





```
echo BLAH BLAH BLAH
echo Need to finish go dep, etc.
echo BLAH BLAH BLAH
```

If these local repos now differ from _k8s.io/common_,
they can be pushed up to origin:

```
cd $WORK_TARGET
# assure all tests pass
git diff
git push -f origin $BRANCH_NAME
```

where a PR can be made against _k8s.io/common_.

Hopefully any code changes needed can be done
mechanically, e.g. package name changes.
