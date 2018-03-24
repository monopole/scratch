# Compare them

Before running kinflate on the two different instance
directories, review the directory
structure:

<!-- @listFiles @test -->
```
cd /tmp/hello/instances
tree
```


<!-- @compareKinflateOutput -->
```
cd /tmp/hello/
diff \
  <(kinflate inflate -f instances/staging) \
  <(kinflate inflate -f instances/production) |\
  more
```

Look at the output individually:

<!-- @runKinflateStaging @test -->
```
kinflate inflate -f instances/staging
```

<!-- @runKinflateProduction @test -->
```
kinflate inflate -f instances/production
```

Deploy them:

<!-- @deployStaging -->
> ```
> kinflate inflate -f $TUT_APP/staging |\
>     kubectl apply -f -
> ```

<!-- @deployProduction -->
> ```
> kinflate inflate -f $TUT_APP/production |\
>    kubectl apply -f -
> ```

