# Overlays

Create a _staging_ and _production_ overlay:

 * _Staging_ enables a risky feature not enabled in production.
 * _Production_ has a higher replica count.
 * Greetings from servers will differ.

<!-- @overlayDirectories @test -->
```
OVERLAYS=$DEMO_HOME/hello/overlays
mkdir -p $OVERLAYS/staging
mkdir -p $OVERLAYS/production
```

__Next:__ [Staging](staging-manifest)
