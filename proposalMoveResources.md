## Proposal - move resources and validation code into k8s.io/common

__Author__: Jeff  Regan @monopole

__Status__: Proposal

### abstract

[DAM]: https://goo.gl/T66ZcD

We want to write a [DAM]-enabling prototype called
[`kexpand`].

This doc describes work to do to allow `kexpand`
development in a way that improves, rather than
worsens, the relationship of these repositories:

* [_k8s.io/kubernetes_] -- core kubernetes components;
  kubelet, scheduler, etc.
* [_k8s.io/kubectl_] -- home to `kexpand`
  and eventual home of `kubectl`.
* [_k8s.io/common_] -- code shared by `kexpand`,
  `kubectl` and the core.

[`kexpand`]: https://github.com/kubernetes/kubectl/tree/master/cmd/kexpand
[_k8s.io/kubernetes_]: https://github.com/kubernetes/kubernetes
[_k8s.io/kubectl_]: https://github.com/kubernetes/kubectl
[_k8s.io/common_]: https://github.com/kubernetes/common
[_k8s.io/apimachinery_]: https://github.com/kubernetes/apimachinery
[_k8s.io/client-go_]: https://github.com/kubernetes/client-go


`kexpand` wants to vendor shared code from
_k8s.io/common_, rather than from
_k8s.io/kubernetes_.  This means moving code
(primarily `resources` and `validation`) from one
repo to another without breaking everyone.

[50475]: https://github.com/kubernetes/kubernetes/issues/50475
[598]: https://github.com/kubernetes/community/pull/598

### background


`kubectl` currently lives in _k8s.io/kubernetes_,
the so-called core repo.  Packages in this repo
are not intended for vendoring.  OTOH, packages in
[_k8s.io/client-go_] and (to some extent)
[_k8s.io/apimachinery_] are intended for
vendoring.

It's generally agreed that `kubectl`, a program
that's supposed to be a pure API client with no
dependencies on core code, [should move][598] out
of _k8s.io/kubernetes_ and into _k8s.io/kubectl_,
hence the name of the latter repo.  Likewise no
new command line API clients should appear in
core.

Such a move requires additional repos, repos like
_k8s.io/utils_ and _k8s.io/common_, to hold code
_shared_ by `kubectl`, `kubernetes`, and
now `kexpand`.

Moving code requires

1. Copying code, retaining git history.
1. Arranging for the code to get the
   deps it needs in its new location.
1. Repairing things in the original location
   by vendoring in the copied code.
1. Deleting the now un-used code from
   its original location.

This is part of the big problem of detangling
_k8s.io/kubernetes_.  We want to start working on
`kexpand` before everything is detangled, but do
so in a way that helps improve the overall
situation rather than making it worse.  Rejected
schemes include building `kexpand` in the core
repo (introducing yet another extraction problem),
and building `kexpand` by vendoring in _all_ of
_k8s.io/kubernetes_, solving problems that
creates, while doing nothing towards moving code
out of core into to repos meant for vendoring.

### Specifics

Below find a script that _locally_ moves code from
_k8s.io/kubernetes_
<blockquote>
<pre>
{project}/      {repo}/   {path}
   k8s.io/  kubernetes/   pkg/api
   k8s.io/  kubernetes/   pkg/kubectl/resource
   k8s.io/  kubernetes/   pkg/kubectl/validation
</pre>
to respective directories in _k8s.io/common_:
<pre>
   k8s.io/      common/   pkg/api
   k8s.io/      common/   resource
   k8s.io/      common/   validation
</pre>
</blockquote>

This informs and emulates the desired end state of
`validation` and `resources` living in
_k8s.io/common_.  Nobody wants `pkg/api` to live
there too, since it holds unversioned types that
are not part of a public API.  Nevertheless it
temporarily needs to be copied too since
`validation` and `resources` depend on it.

Two projects can now proceed independently.

#### 1) `kexpand` work

Dev cycle something like

 * Come to work in the morning and refresh copied code.

   * For a time (see project 2 below) treat
     _k8s.io/common_ as a generated, non-canonical
     repo.  Its `README` should label the repo as
     a generated copy of certain directories from
     _k8s.io/kubernetes_.

   * Use the script below to copy code from a local
     clone of _k8s.io/kubernetes_ to a local clone
     of _k8s.io/common_, preserving history and
     adapting the code as needed.

   * Diff local _k8s.io/common_ against upstream,
     and if it has sufficiently changed, push it
     upstream into github.

   * cd into _k8s.io/kubectl_ and run
     the [`dep`] tool to vendor from
     _k8s.io/common_ into _k8s.io/kubectl/vendor_.

   * Push _k8s.io/kubectl/vendor_ changes upstream.

 * Make improvements to `kexpand` in
   _k8s.io/kubectl_.

 * Push `kexpand` changes upstream.

[`dep`]: https://github.com/golang/dep

The upshot is that `kexpand` will be built to
vendor from _k8s.io/common_ which is the desired
final state, but without first requiring the work
needed to make _k8s.io/common_ "normal" repo

#### 2) make _k8s.io/common_ a "normal" repo

In parallel to the above, a project can move the
code for real:

 * Add a warning to _k8s.io/common/README.md_
   explaining that the repo is merely a mirror and
   should not accept changes (as is done for
   [_k8s.io/apimachinery_]).

 * Within _k8s.io/kubernetes_, break `validation`'s
   dependence on `pkg/api`.

 * Per work above, `validation` and `resources`
   are already periodically copied to
   _k8s.io/common_ preserving git history.

 * In _k8s.io/kubernetes_, start a PR by
   actually __deleting__
   `validation` and `resources`.

 * Finish that PR by modifing all code in
   _k8s.io/kubernetes_ (i.e. the `kubectl`
   program) to vendor `validation` and `resources`
   from _k8s.io/common_ instead.  Commit the
   change.

 * Remove the warning in
   _k8s.io/common/README.md_; the repo now a
   normal repository containing the canonical
   `validation` and `resources` source code.


### The morning code copy script

Define the repos involved - in this case personal
github forks from _kubernetes_:

```
GH_USER_NAME=monopole
REPO_SOURCE=$GH_USER_NAME/kubernetes
REPO_TARGET=$GH_USER_NAME/common
```

Clone the target repo.  This is where we want
_common_ code to land, and it's the code that a
local version of `kexpand` will depend on (via
the `dep` tool).

This directory will be recreated often, hence its a tmp dir.
```
WORK_TARGET=$(mktemp -d)
git clone https://github.com/$REPO_TARGET $WORK_TARGET
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
  local BRANCH_NAME=contentMove
  local REMOTE_NAME=whatever

  # Place to clone it.
  local WORK_SOURCE=$(mktemp -d)

  git clone \
      https://github.com/$REPO_SOURCE \
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
  git checkout master
  git checkout -b $BRANCH_NAME

  git remote add $REMOTE_NAME $WORK_SOURCE
  git fetch $REMOTE_NAME
  git merge --allow-unrelated-histories \
      $REMOTE_NAME/$BRANCH_NAME
  git remote rm $REMOTE_NAME

  # Delete the traumatized `$WORK_SOURCE` directory.
  rm -rf $WORK_SOURCE

  # TODO: Peform package name changes via sed, awk etc.
}
```

Do the actual copy:

```
copyDirectory pkg/api                pkg/api
copyDirectory pkg/kubectl/validation validation
copyDirectory pkg/kubectl/resource   resource
```

This leaves `$WORK_TARGET`, a clone of _k8s.io/common_,
with fresh copies of the three directories.

If these local repos now differ from the origin, they
can be pushed up to origin:

```
cd $WORK_TARGET
# assure all tests pass
git diff
git push -f origin $BRANCH_NAME
```

where a PR can be made against _k8s.io/common_.

Hopefully any code changes needed can be done
mechanically, e.g. package name changes.
