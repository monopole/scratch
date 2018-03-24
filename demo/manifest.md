# Base Manifest

The `base` directory has a _manifest_:

<!-- @manifest @test -->
```
BASE=$DEMO_HOME/hello/base
more $BASE/Kube-manifest.yaml
```
Run kinflate on the base; the customized resources are
emitted to `stdout`:

<!-- @manifest @test -->
```
kinflate inflate -f $BASE
```

__Next:__ [Customize it](customize)
