# Github repo copy script.

# Copies contents of
#    https://github.com/$SOURCE_GH_ORG/$SOURCE_GH_REPO/$SOURCE_PATH
# to
#    https://github.com/$TARGET_GH_ORG/$TARGET_GH_REPO/$TARGET_PATH
# retaining history.
#
# Not general,

# It's assumed that $TARGET_REPO exists, and that
# $TARGET_PATH does not already exist in $TARGET_REPO.

# End result is a branch in a clone of $TARGET_REPO
# with a new branch containing the new content.

# User can then edit, commit and push.

function reportIt {
  echo " "
  echo "----------------------------------------------------"
  echo $@
  echo "----------------------------------------------------"
}

function copyDirectory {
  local SOURCE_PATH=$1
  local TARGET_PATH=$2

  # These branches should not exist anywhere.
  local SOURCE_BRANCH=bulk_move_packing

  # Clone the source.
  local SOURCE_CLONE=$(mktemp -d)
  reportIt "Cloning source $SOURCE_GH_ORG/$SOURCE_GH_REPO to $SOURCE_CLONE ..."
  git clone \
      https://github.com/$SOURCE_GH_ORG/$SOURCE_GH_REPO \
      $SOURCE_CLONE

  cd $SOURCE_CLONE
  git checkout -b $SOURCE_BRANCH

  # Delete everything in the source repo
  # except the files to move:
  reportIt "Deleting undesired content."
  git filter-branch \
    --subdirectory-filter $SOURCE_PATH \
    -- --all

  # Show what's left
  ls

  # Still at the top of the $SOURCE_CLONE directory,
  # move retained content to the target directory in
  # the target repo.
  mkdir -p $TARGET_PATH

  # The -k avoids the error from '*' picking
  # up the target directory itself.
  reportIt "Moving desired content to desired location."
  git mv -k * $TARGET_PATH

  # The $SOURCE_CLONE directory now contains only the
  # desired content, moved to its desired position with
  # respect to where it will soon land in the
  # TARGET_REPO.  Commit the branch locally.
  git commit -m "Isolated content of $SOURCE_PATH"

  cd $TARGET_CLONE
  # The following branch should already exist.
  git checkout $TARGET_BRANCH

  local REMOTE_NAME=totallyArbitrary
  git remote add $REMOTE_NAME $SOURCE_CLONE
  git fetch $REMOTE_NAME
  reportIt "Merging desired content from $SOURCE_PATH ..."
  git merge \
      --allow-unrelated-histories \
      -m "Copying $SOURCE_PATH" \
      $REMOTE_NAME/$SOURCE_BRANCH
  git remote rm $REMOTE_NAME

  reportIt "Removing traumatized $SOURCE_CLONE directory."
  rm -rf $SOURCE_CLONE
}

function prepTheBranch {

  # Prepare the target.
  TARGET_TMP=$(mktemp -d)
  TARGET_CLONE=$TARGET_TMP/src/github.com/$TARGET_GH_ORG/$TARGET_GH_REPO
  mkdir -p $TARGET_CLONE

  reportIt "Cloning $TARGET_GH_ORG/$TARGET_GH_REPO to $TARGET_CLONE ..."
  git clone \
      https://github.com/$TARGET_GH_ORG/$TARGET_GH_REPO \
      $TARGET_CLONE
  cd $TARGET_CLONE
  TARGET_BRANCH=bulk_move_unpacking
  reportIt "Creating empty target branch."
  git checkout -b $TARGET_BRANCH

  copyDirectory cmd/kustomize .
  copyDirectory pkg/kustomize pkg
  copyDirectory pkg/loader pkg/loader
  copyDirectory bin bin

  reportIt "Current directory: $TARGET_CLONE"
  git status
  git remote -v
  git branch
  reportIt "Make any final edits (e.g. go imports) then commit and push."
}

function buildIt {
  GOPATH=$TARGET_TMP go build github.com/$TARGET_GH_ORG/$TARGET_GH_REPO/$1
}

function getIt {
# GOPATH=$TARGET_TMP go get $1
  GOPATH=$TARGET_TMP dep ensure -add $1
}

function adjustImport {
  local file=$1
  local old=$2
  local new=$3
  local c="s|\\\"$old/|\\\"$new/|"
  sed -i $c $file
  local c="s|\\\"$old\\\"|\\\"$new\\\"|"
  sed -i $c $file
}

function switchImports {
  for i in $(find . -name '*.go' );
  do
    adjustImport $i \
      k8s.io/$SOURCE_GH_REPO/$1 \
      github.com/$TARGET_GH_ORG/$TARGET_GH_REPO/$2
  done
}

function goFmtAll {
  reportIt "Reformatting."
  for i in $(find . -name '*.go' );
  do
    gofmt -w $i
    goimports -w $i
  done
}

SOURCE_GH_ORG=kubernetes
SOURCE_GH_REPO=kubectl

TARGET_GH_ORG=monopole
TARGET_GH_REPO=kustomize

prepTheBranch

cd $TARGET_CLONE

reportIt "Swapping imports."
switchImports pkg/kustomize/app                pkg/app
switchImports pkg/kustomize/commands           pkg/commands
switchImports pkg/kustomize/configmapandsecret pkg/configmapandsecret
switchImports pkg/kustomize/constants          pkg/constants
switchImports pkg/kustomize/hash               pkg/hash
switchImports pkg/kustomize/internal           pkg/internal
switchImports pkg/kustomize/resource           pkg/resource
switchImports pkg/kustomize/transformers       pkg/transformers
switchImports pkg/kustomize/types              pkg/types
switchImports pkg/kustomize/util/fs            pkg/util/fs
switchImports pkg/kustomize/util               pkg/util
switchImports pkg/loader                       pkg/loader
switchImports cmd/kustomize/version            version

GOPATH=$TARGET_TMP goFmtAll

reportIt "Vendoring in deps."
GOPATH=$TARGET_TMP dep init

GOPATH=$TARGET_TMP go test github.com/$TARGET_GH_ORG/$TARGET_GH_REPO/...
GOPATH=$TARGET_TMP go install github.com/$TARGET_GH_ORG/$TARGET_GH_REPO

$TARGET_TMP/bin/kustomize

reportIt "All done, continue with these steps:"

cat <<EOF
Edit bin/pre-commit.sh as follows:

Add a tail in the pipe:  go list -f '{{.Dir}}' ./... | tail -n +2 | tr '\n' '\0'

Modify mdrip command argument, ./cmd/kustomize becomes ./demos

After that, try running the pre-commit script:

  GOPATH=$TARGET_TMP ./bin/pre-commit.sh

Don't forget to copy ~/gopath1/src/k8s.io/kubectl/.travis.yml

Run these commands to stage the repo:

  gob-ctl delete user/$USER/kustomize
  gob-ctl create user/$USER/kustomize
  git add Gopkg.lock
  git add Gopkg.toml
  git add vendor/
  git commit -a -m "Bulk move from k8s/kubectl"
  git checkout master
  git rebase bulk_move_unpacking
  git push -f -o nokeycheck sso://user/jregan/kustomize master
  gob-ctl acl user/$USER/kustomize -reader all_users

See https://user.git.corp.google.com/jregan/kustomize/

See https://g3doc.corp.google.com/company/teams/opensource/releasing/preparing.md?cl=head#stage-your-code-for-review

EOF
