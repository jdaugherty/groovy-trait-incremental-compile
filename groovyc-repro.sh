#!/usr/bin/env bash
# The same difference with groovyc alone, no build tool involved. Needs groovyc on the PATH (any Groovy 4 or 5).
set -euo pipefail
cd "$(dirname "$0")"
command -v groovyc > /dev/null || { echo "groovyc not found on the PATH"; exit 1; }

SRC=lib/src/main/groovy/example
OUT=build/groovyc
rm -rf "$OUT"
mkdir -p "$OUT/together" "$OUT/trait-first" "$OUT/impl-second"

echo "== Thing compiled together with the trait"
groovyc -d "$OUT/together" "$SRC/Flag.groovy" "$SRC/Named.groovy" "$SRC/Util.groovy" "$SRC/Thing.groovy"
echo "== Thing compiled against the precompiled trait"
groovyc -d "$OUT/trait-first" "$SRC/Flag.groovy" "$SRC/Named.groovy" "$SRC/Util.groovy"
groovyc -d "$OUT/impl-second" -cp "$OUT/trait-first" "$SRC/Thing.groovy"

echo "== difference in Thing.class (constant pool indices stripped):"
diff <(javap -v -p "$OUT/together/example/Thing.class" | sed -n '/^{/,$p' | sed -E 's/#[0-9]+//g; s/ +/ /g') \
     <(javap -v -p "$OUT/impl-second/example/Thing.class" | sed -n '/^{/,$p' | sed -E 's/#[0-9]+//g; s/ +/ /g') \
     | grep -v invokevirtual || true
