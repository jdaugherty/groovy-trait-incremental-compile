#!/usr/bin/env bash
# Shows that an incremental build changes Thing.class although Thing.groovy did not change, and that the
# downstream project recompiles because of it. Restores the source it edits.
set -euo pipefail
cd "$(dirname "$0")"

UTIL=lib/src/main/groovy/example/Util.groovy
OUT=build/demo
mkdir -p "$OUT"

echo "== 1. Full build: the trait and Thing are compiled together"
./gradlew --console=plain -q :app:compileGroovy
cp lib/build/classes/groovy/main/example/Thing.class "$OUT/Thing-full.class"

echo
echo "== 2. Change a method body in Util, which Thing uses only inside a method body"
sed -i.bak "s/'hello'/'hello, world'/" "$UTIL"
trap 'mv "$UTIL.bak" "$UTIL"' EXIT

echo
echo "== 3. Incremental build: Thing is recompiled alone, against the precompiled trait"
./gradlew --console=plain --info :app:compileGroovy | grep -E "Task :(lib|app):compileGroovy|Incremental compilation of|is not up-to-date because|Input property 'classpath'" || true
cp lib/build/classes/groovy/main/example/Thing.class "$OUT/Thing-incremental.class"

echo
echo "== 4. Thing.groovy did not change, but Thing.class did (constant pool indices stripped):"
diff <(javap -v -p "$OUT/Thing-full.class" | sed -n '/^{/,$p' | sed -E 's/#[0-9]+//g; s/ +/ /g') \
     <(javap -v -p "$OUT/Thing-incremental.class" | sed -n '/^{/,$p' | sed -E 's/#[0-9]+//g; s/ +/ /g') \
     | grep -v invokevirtual || true
