package example

class App {
    static void main(String[] args) {
        Thing thing = new Thing()
        println "${thing.describe()}: ${thing.go()}"
    }
}
