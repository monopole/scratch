# Kinflate Demo

Goal:

 1. Clone a simple off-the-shelf example as a base configuration.
 1. Customize it.
 1. Create two different instances based on the customization.

First install the tool:

<!-- @install @test -->
```
go get k8s.io/kubectl/cmd/kinflate
```

Define a place to work on local disk:

<!-- @clear @test -->
```
DEMO_HOME=$(mktemp -d)
```

__Next:__ [Clone an Example](clone)
