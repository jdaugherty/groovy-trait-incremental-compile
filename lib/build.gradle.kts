plugins {
    groovy
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.apache.groovy:groovy:4.0.33")
}

tasks.withType<GroovyCompile>().configureEach {
    options.isIncremental = true
}
