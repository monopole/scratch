# Deploy

The individual resource sets are:

<!-- @runKinflateStaging @test -->
```
kinflate inflate -f $DEMO_HOME/overlays/staging
```

<!-- @runKinflateProduction @test -->
```
kinflate inflate -f $DEMO_HOME/overlays/production
```

To deploy, pipe the above commands to kubectl apply:

> ```
> kinflate inflate -f $DEMO_HOME/overlays/staging |\
>     kubectl apply -f -
> ```

> ```
> kinflate inflate -f $DEMO_HOME/overlays/production |\
>    kubectl apply -f -
> ```
