# Clone

You want to run the _hello_ service.

Find an [off-the-shelf config](https://github.com/kinflate/example-hello)
for it, then clone it:

<!-- @cloneIt @test -->
```
cd $DEMO_HOME
mkdir hello
git clone \
    https://github.com/kinflate/example-hello \
    hello/base
```

The current layout is:
<!-- @seeBase @test -->
```
tree $DEMO_HOME/hello
```

One could immediately apply these resources to a cluster:

> ```
> kubectl apply -f $DEMO_HOME/hello/base
> ```

to instantiate the _hello_ service in an uncustomized form.

__Next:__ [The Base Manifest](manifest)
