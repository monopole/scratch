# Compare them

Review the directory structure:

<!-- @listFiles @test -->
```
tree $DEMO_HOME
```

<!-- @compareKinflateOutput -->
```
diff \
  <(kinflate inflate -f $DEMO_HOME/overlays/staging) \
  <(kinflate inflate -f $DEMO_HOME/overlays/production) |\
  more
```

__Next:__ [Deploy](deploy)
