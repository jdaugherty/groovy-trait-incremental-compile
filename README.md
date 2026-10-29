# A Groovy trait's implementer compiles differently when the trait is precompiled

A class that implements a trait compiles to a different class file depending on whether the trait is
in the same compilation unit or already compiled. The class file is semantically the same, but its
bytes and its binary API are not, so incremental builds that recompile the implementer alone produce
a changed class from unchanged source, and everything downstream recompiles.

Reproduced with Groovy 4.0.33 and 5.1.3 on JDK 25.

## The difference

Three files in `lib/src/main/groovy/example`:

```groovy
@Retention(RetentionPolicy.RUNTIME) @Target(ElementType.METHOD)
@interface Flag { boolean value() default true; String note() default '' }

trait Named {
    @Flag
    String describe() { 'named' }
}

class Thing implements Named {
    String go() { Util.greeting() }
}
```

Compile `Thing` together with the trait, and again against the precompiled trait. `javap -v` on the two
`Thing.class` files shows exactly two differences:

```
-        example.Flag                                  trait in the same compilation unit
+        example.Flag(note="", value=true)              trait precompiled

-InnerClasses:                                         trait in the same compilation unit only
-  public static abstract Helper=class example/Named$Trait$Helper of class example/Named
```

`groovyc-repro.sh` does this with `groovyc` alone, no build tool involved.

## In an incremental build

`demo.sh` runs the same thing through Gradle 9.8.0 with incremental Groovy compilation and the
`GROOVY_COMPILATION_AVOIDANCE` feature preview:

1. a full build of `:app`, where `lib` compiles the trait and `Thing` together;
2. a change to a method body in `Util`, which `Thing` uses only inside a method body;
3. an incremental build, where `lib` recompiles `Util` and `Thing` only, against the precompiled trait.

```
> Task :lib:compileGroovy
Incremental compilation of 2 classes completed in 0.55 secs.
> Task :app:compileGroovy
Task ':app:compileGroovy' is not up-to-date because:
  Input property 'classpath' file .../lib/build/libs/lib.jar has changed.
```

`Thing.groovy` did not change, but `Thing.class` did, and since annotation values are part of the ABI,
the downstream `app` project recompiles. In a project where many classes implement a trait, such as
a Grails application whose domain classes share a few project traits, a body-only change in one
utility class ends up recompiling most of every downstream module.

## Cause

When the trait is in the compilation unit, `TraitComposer` copies the trait's methods from its AST:
annotations keep the members written in the source, and the helper is an `InnerClassNode` of the
trait, which puts an `InnerClasses` entry into the implementer.

When the trait is precompiled, `Traits.findHelpers` loads the helper class through the class loader
and wraps it with `ClassHelper.make(Class)`, so its methods come from `Java8.configureClassNode`,
which builds the `AnnotationNode`s from reflected `java.lang.annotation.Annotation` instances.
Reflection reports every member, defaults included, so each annotation is written out in full, and
the helper is a plain `ClassNode`, so no `InnerClasses` entry is recorded.

Any runtime- or class-retained annotation on a trait method shows it; `@DelegatesTo` on a trait
method parameter shows it the same way. Groovy's own source-retained transforms do not.

## Suggested fix

Resolve precompiled trait helpers the way every other class on the classpath is resolved, from
bytecode through the compilation unit's `ClassNodeResolver`, instead of loading them into the JVM
and reflecting. A decompiled `ClassNode` carries annotations exactly as the class file has them, so
the two paths would agree, and the `InnerClasses` entry could then be made consistent in either
direction.

This would also remove the one place where the compiler has to *load* a class of the previous
output. That loading is what fails with `NoClassDefFoundError` in incremental compilation when a
class the helper refers to has been moved aside for recompilation, see
[GROOVY-10932](https://issues.apache.org/jira/browse/GROOVY-10932) and
[gradle/gradle#39622](https://github.com/gradle/gradle/pull/39622).

A smaller alternative is to drop annotation members equal to their default in
`Java8.setAnnotationMetaData`, using `Method.getDefaultValue()`, which covers the annotation half
only.

## Running it

```
./demo.sh           # Gradle: full build, body change, incremental build, diff of Thing.class
./groovyc-repro.sh  # groovyc alone; needs groovyc on the PATH
```

Both scripts leave the sources as they found them.
