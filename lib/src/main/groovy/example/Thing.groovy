package example

/**
 * Implements the trait, and uses Util only inside a method body: a change to Util's method bodies makes
 * incremental compilation recompile Thing, alone, against the already compiled trait.
 */
class Thing implements Named {
    String go() { Util.greeting() }
}
