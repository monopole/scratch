# Why and how to move on from vars.

Kustomize has a _vars_ feature that shipped early in
the project.  The project's view of its purpose and
direction has focussed since then, and the feature now
appears as a outlier in the kustomize feature set
for reasons discussed below.

This issue is a parent issue to gather discussion about
vars, and see if there are a set of common problems
that could be solved by a few targetted transformers or
generators (that don't use vars).

This would allow a migration path to deprecate vars.

## What’s a var?

A _var_ in kustomize is a reflection mechanism,
allowing a value defined in one YAML configuration
field (e.g. an IP address) to be copied to other
locations in the YAML.  It has a source spec and any
number of targets.

[var field]: https://github.com/kubernetes-sigs/kustomize/blob/a280cdf5eeb748f5a72c8d94164ffdd68d03c5ce/docs/fields.md#vars

 - __source spec__: a [field in a kustomization.yaml
   file][var field] associating an uppercase var name like
   `VAR` with a specific field in a specific resource
   instance, e.g. the image name in the Deployment named
   _production_.  This field is the source of the var’s
   value.

 - __targets__: instances of the string `$VAR` in resource
   instance fields, identifying where to put the var’s
   value.  The placement of `$VAR` is constrained to a particular
   set of fields in a particular set of resources.

It’s a DRY (don’t repeat yourself) feature.  The
overall effect is similar to the reflection provided by
YAML anchors, except that kustomize manages it up the
overlay stack.


## Isn't this templating?

[example-kv]: https://github.com/helm/charts/blob/e002378c13e91bef4a3b0ba718c191ec791ce3f9/stable/artifactory/values.yaml
[example-template]: https://github.com/helm/charts/blob/e002378c13e91bef4a3b0ba718c191ec791ce3f9/stable/artifactory/templates/artifactory-deployment.yaml
[dambible]: https://github.com/kubernetes/community/blob/master/contributors/design-proposals/architecture/declarative-application-management.md
[downward api]: https://kubernetes.io/docs/tasks/inject-data-application/downward-api-volume-expose-pod-information/#the-downward-api
[apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply

A kustomize var smells like a template variable, but
stops short of full templating.

Full templating, with a distinct `key:value` (KV) file,
has drawbacks.

 - A template isn't YAML; it must be rendered
   to make YAML.

   Kustomize allows a `$VAR` only in a limited set of
   string fields like container command arguments
   (similar to the contraints of the [downward API]),
   so the source material remains usable with generic
   YAML tools.

 - KV files become a template-driven API wrapping the real API.

   This is fine in simple cases, but an API emerging
   from templates scales poorly to real world
   production setups - large environments, disparate
   configuration owners, etc.  Kustomize vars avoid the
   distinct KV file by requiring reflection.

 - The ugliness arising from shared
   templates - [everything gets
   parameterized][example-template].

 - The difficulty of rebasing templates to capture
   upstream changes into your template fork.

These drawbacks are discussed in more detail in Brian
Grant's [Declarative application management in
Kubernetes][dambible].

Kustomize vars directly avoid the first two, and help
avoid other problems by simply not being the core means
to generate and customize configuration.

Kustomize vars, however, share one glaring flaw with
template variables.  Their use makes the raw
configuration data unusable in an [apply] operation -
the config data must be passed through kustomize first
before being applied.

This violates an explicit goal of kustomize; provide a
means to manipulate configuration data without making
the raw configuration unusable by kubernetes.
kustomize vars would not now be accepted as a new
feature in their current form.

## Alternatives to vars

### Object transformation

Kustomize vars let one copy data from one field to
others; they aren't meant as a means to inject raw
values.

Template variables, on the other hand, inject raw
values - that's all they do.  Two extremely common uses
of template variables in kubernetes is to set the image
name in a container spec, and set labels on objects.

In kustomize, these two tasks are done with
[transformer plugins][plugin] (respectively, the [image
transformer] and the [label transformer]).

A transformer plugin is a chunk of code written in any language that
 - when run, accepts, modifies and emits YAML,
 - is configurable by a kubernetes style YAML file,
 - can be found and run by kustomize when the path to its config
   file appears in the `transformers:` field
   of a kustomization file.

Transfomers understand the structure of what they
modify; they don't need template variable placeholders
to do their job.

If a use case feels like these, the kustomize way to do
it is write a transformer plugin to perform the field
addition or mutation

[label transformer]: https://github.com/kubernetes-sigs/kustomize/tree/master/plugin/builtin/labeltransformer
[image transformer]: https://github.com/kubernetes-sigs/kustomize/tree/master/plugin/builtin/imagetagtransformer
[kubebuilder]: https://github.com/kubernetes-sigs/kubebuilder/blob/master/README.md
[plugin]: https://github.com/kubernetes-sigs/kustomize/tree/master/docs/plugins
[crds]: https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources


### Object generation

Since vars let one copy data from one field to another,
it might be best to simply make the object or
set of objects with these fields set to the same value
from the outset.

In kustomize, the way to make objects (instead of
reading them from storage) is to use a [generator
plugin][plugin].  It's a chunk of code
written in any language that
 - when run, emits kubernetes-style YAML,
 - is configurable by a kubernetes-style YAML config file,
 - can be found and run by kustomize when the path to its config
   file appears in the `generators:` field
   in a kustomization file.

A frequent use case for generators is kubernetes
[Secret] generation.  There's a [builtin secret
generator] plugin, and the documentation has an
[example][dbSecret] of a plugin that produces Secrets
from a database.

[Secret]: https://kubernetes.io/docs/concepts/configuration/secret
[dbSecret]: https://github.com/kubernetes-sigs/kustomize/blob/master/examples/secretGeneratorPlugin.md#secret-values-from-anywhere
[builtin secret generator]: https://github.com/kubernetes-sigs/kustomize/blob/master/plugin/builtin/secretgenerator

A plugin's config file holds values that would
otherwise appear as part of a KV file.  In the template
world, it's possible to define keys as JSON paths (YAML
is a superset of JSON) so that the [KV file looks like
a YAML object][example-kv].  There is, however, no real
object here.  The user must rely on the branching and
looping constructs of the template to do anything other
than replace keys with these values.

A kustomize generator can and should have documentation
and unit tests - it's a tangible, testable factory.
The plugin and it's config file provide the full
factory abstraction missing in the template approach.

Kustomize is just a finder and runner of generator and
transformer plugins, controlled by _declarations_ in
`kustomization.yaml` files and the YAML files it
references.  The kustomize libraries offer a framework
for writing generator and transformer plugin unit
tests.

#### custom resources

While on the topic of object generation and the notion
that KV files can be viewed as constructor arguments,
it's appropriate to mention custom resources.

Given a set of related, live kubernetes objects - how
can they be instantiated as one meaningful, monitorable
thing with a life of its own?  [Custom resources][crds]
are the answer to this question, and the general answer
to extending the kubernetes API with more objects.

[Kubebuilder][kubebuilder] is a tool to help write the
controller that accompanies a custom resource
definition in the kubernetes control plane.

Like any other kubernetes API YAML, custom resource
configuration can be generated or transformed by
kustomize.


### Are kustomize vars necessary?

They are useful as a stopgap, when one cannot both
reframe a problem as generation or transformation, and
find (or write) the generator or transformer plugin
that does the job.

The problem is that - from a template-user point of
view - they feel incomplete.  They inspire
template-like configuration management and related
feature requests.  There's an urge to _generalize_
kustomize vars to provide full templating and/or
language-like scoping.  This must be resisted.

The kustomize approach is to eschew the temptation to
generalize, and solve specific kuberenetes
configuration problems with a dedicated generator or
transformer that, itself, is easily configured.


## Issue Survey

The following attempts to capture and categorize issues
related to kustomize vars.

### I want to put `$VAR` in some (currently disallowed) field

[var transformer]: https://github.com/kubernetes-sigs/kustomize/blob/a280cdf5eeb748f5a72c8d94164ffdd68d03c5ce/api/internal/accumulator/refvartransformer.go#L26

[varreference.go]: https://github.com/kubernetes-sigs/kustomize/blob/a280cdf5eeb748f5a72c8d94164ffdd68d03c5ce/api/konfig/builtinpluginconsts/varreference.go

[`Configurations`]: https://github.com/kubernetes-sigs/kustomize/blob/master/api/types/kustomization.go#L112
[examples]: https://github.com/kubernetes-sigs/kustomize/tree/master/examples/transformerconfigs
[test1]: https://github.com/kubernetes-sigs/kustomize/blob/master/api/krusty/customconfig_test.go
[test2]: https://github.com/kubernetes-sigs/kustomize/blob/master/api/krusty/transformersimage_test.go

kustomize doesn't allow unstructured `$VAR` placement.
A `$VAR` must go into a field, and only into a
particular set of fields.

Kustomize vars are handled by the [var transformer].
Like all other builtin transformers, it has a builtin
configuration, in its case defined in the file
[varreference.go].  This file defines where `$VAR` can
be placed in configuration yaml.

One can use the [`Configurations`] field in any
kustomization file (see this [test][test1], this other
[test][test2] and these [examples]) to specify a file
containing a custom set of field specs in the same
format as varreference.go.  This allows a user to add a
`$VAR` to more string fields without changing kustomize
code.

#### The var transformer is a singleton with global scope

Kustomize plugin transformers have no effect beyond the
kustomization directory tree in whose root they are
declared.  Further, in one kustomization directory one
may use many different instances of the same
transformer - e.g.  one can declare multiple label
transformers that add different labels to different
objects.

The var transformer, however, is special - it's a
singleton with global scope.  When var transformer
configuration data is declared in a kustomization file,
it's not immediately used, and is instead merged with
any var transformer configuration data already read.
The last step of a `kustomize build` is to take all
accumulated var configuration, build a singleton var
transformer, and run it over all objects in view.

The upshot is that one can put var definitions and var
transformer configuration anywhere (in any
kustomization.yaml file reachable from the
kustomization file targetted by a `kustomize build`
command) and get the same global effect.

This global behavior came from early requests to have
var definitions propagate up, so that overlays could
usefully decare `$VARs` in their patches.


#### Some issues

 - [Variable substitution only partly working on Jobs](https://github.com/kubernetes-sigs/kustomize/issues/1782)
 - [well-defined vars that were never replaced](https://github.com/kubernetes-sigs/kustomize/issues/1734)
 - [Kustomize vars not applied to Namespace resources](https://github.com/kubernetes-sigs/kustomize/issues/1713)
 - [Can't use kustomize vars in images](https://github.com/kubernetes-sigs/kustomize/issues/1592)
 - [var replacement doesn't occur on commonLabels](https://github.com/kubernetes-sigs/kustomize/issues/1585)
 - [Using overlay-provided secrets in a base](https://github.com/kubernetes-sigs/kustomize/issues/1553)
 - [Var reference does not work in volumes](https://github.com/kubernetes-sigs/kustomize/issues/1540)

TODO: dig out the actual problems here, and find/write
the transformer that solves that problem.

### I want to define vars that aren’t strings

It so happens that the current implementation of vars only
allows strings, because only string fields (container
command line args and mount paths) are allowed by default,
and the yaml libraries in use make a distinction between
fields of string, number, map, etc.

Relaxing this is straightforward (a bit more code, tests,
and error handling) but pointless if vars are deprecated.


#### Some issues
 - [Variable is expected to be string](https://github.com/kubernetes-sigs/kustomize/issues/1721)

### I want to use diamonds

Suppose one has a top level overlay, called `all`, that
merges sibling levels `dev`, `staging`, `prod` (variants) by
specifying them as resources - i.e. the file
`all/kustomization.yaml` contains:

```
resources:
- ../prod
- ../staging
- ../dev
```

Suppose in turn that these variants modify a common base.
A var defined in that common base will be defined three
times at the `all` level, a currently disallowed behavior.

This is analogous to the compiler rejecting a construct like

```
type Bar struct {
  someVar int
}
type Foo struct {
  Bar
  Bar
}
```

[pr/1620]: https://github.com/kubernetes-sigs/kustomize/pull/2012

@tkellen proposes a fix for this, [pr/1620], allowing
repeatedly defined var names as long as the source of
the underlying value can be shown to be the same.

The solution works for particular use cases, but leaves
us with a global vars that will sometimes work and
sometimes not work.  When  they don't work - when the
values don't match - what should the error encourage
the user to do?  Rename/re-arrange vars?  Or do
something else entirely?

If vars are retained, and get more complex scope and
reedefinition rules, then there should be a clear
design associated with them.  We don't need that design
to know that it would be a firm step into configuration
language territory, a non-goal of kustomize.

#### Meta question: why do users construct diamonds?

Possibly for one-shot [apply] operations?  With the above
kustomization file, one can deploy all environments
with one command:

```
result=$(kustomize build all | kubectl apply -f -)
```

The price of this convenience is a completely useless result
from apply, analogous to conflating the purchase of real
estate, a car and a sandwich to one financial transaction,
and accepting that it must all be undone because the
sandwich had onions you didn't order.

A far better way to do this as one command is make a
scripted loop which can analyze the [apply] result for each
environment:

```
for env in 'prod staging dev'; do
   result=$(kustomize build $env | kubectl apply -f -)
   handle(result)
done
```

#### Some issues

 - [don't cause variable conflicts when values are the
    same](https://github.com/kubernetes-sigs/kustomize/issues/1600)

 - [Error when composing several identical bases that use
the same var: "var ... already encountered](https://github.com/kubernetes-sigs/kustomize/issues/1248)

[configmap generator]: https://github.com/kubernetes-sigs/kustomize/blob/master/examples/configGeneration.md

### I just want a simple KV file

Here a user wants to get the value for the vars from
some external KV file, rather than reflexively from
some other part of the config.

One reason not to do this is that there's already a
mechanism to convert KV files _and other data
representations_ into
[configmaps][configmap generator], and vars already
know how to source configmaps, so let's try that first.
The purpose of configmaps is to hold miscellaneous
config data intended for container shell variables and
command line arguments; they're aligned with the intent
of kustomize vars.  Having the configmaps in the
cluster has other advantages, and no downside outside
a questionable concern that configmaps will forever
accumulate in storage.

Another reason not to do this has already been covered.

It would place kustomize firmly in the template
business, which is a non-goal of kustomize.  Kustomize
users that _really_ want to use some templating can do
so using some other tool - sed, jinja, erb, envsubst,
kafka, helm, ksonnet, etc. - as the first stage in
configuration rendering.

It's possible to use a kustomize generator plugin to
drive such a tool (e.g. [sed example], [helm example])
in this first stage, hopefully as a first step in
coverting away from template use entirely.


[sed example]: https://github.com/kubernetes-sigs/kustomize/tree/master/plugin/someteam.example.com/v1/sedtransformer

[helm example]: https://github.com/kubernetes-sigs/kustomize/tree/master/plugin/someteam.example.com/v1/chartinflator

### Some issues

 - [Enhancement: Literal vars](https://github.com/kubernetes-sigs/kustomize/issues/318)
 - [Support for variable replacement in literals](https://github.com/kubernetes-sigs/kustomize/issues/1737)

## Proposed Alternatives

### Replacement Transformer

[replacements POC]: https://github.com/kubernetes-sigs/kustomize/pull/1631
[prefix/suffix transformer]: https://github.com/kubernetes-sigs/kustomize/tree/master/plugin/builtin/prefixsuffixtransformer

Coded up as an example transformer in #1631 ([replacements POC]).

The idea here is simple: eliminate embedding `$VAR` as
the means of defining the _target_, replacing target
specification with kind/field addresses in the
kustomization file (as is already done for sources).

This keeps the raw material usable - no sprinkling of
dollar variables throughout the config.

There’s a loss of functionality though. In the existing
vars implementation, the `$VAR` can be embedded in a
container command line string.  I.e., one can replace
_part_ of a string field.

The atomic unit of replacement of this transformer is
the whole field.  If your command line is a _list_ of
arguments (instead of one blank-delimitted string), the
replacements transformer should be able to target list
entries by index.

You still have a problem, however, if you want to build path
strings on the way up a configuration.

That problem, however, could be more directly solved by
a transformer dedicated to path modification, just as
the [prefix/suffix transformer] is dedicated to name
transformation.

### Annotations
