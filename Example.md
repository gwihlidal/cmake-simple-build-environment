### Prerequisites ###

Install Simple Build Environment. [See Installation](Installation.md).

### Try ###

I use linux Debian, but it should work on any other system.

  1. open shell
    * On Linux use your favorite shell
    * On windows use `Visual Studio 20xx Command Prompt`
  1. checkout [HelloWorld](http://code.google.com/p/sbe-helloworld)
    * `svn checkout http://sbe-helloworld.googlecode.com/svn/trunk sbe-helloworld-read-only`
  1. create build directory
    * `cd sbe-helloworld-read-only`
    * `mkdir build`
    * `cd build`
  1. configure
    * On linux
      * `cmake ..`
    * On windows
      * `cmake -G "NMake Makefiles" ..`
  1. run tests
    * On linux
      * `make test`
    * On windows
      * `nmake test`

You will see
  * how dependencies are exported and installed for [HelloWorld](http://code.google.com/p/sbe-helloworld)
  * How test are build and executed

You can find Dependency graph in `dependencies/info/DependecyGraph.png`

![http://cmake-simple-build-environment.googlecode.com/svn/wiki/images/DependecyGraphHelloWorld.png](http://cmake-simple-build-environment.googlecode.com/svn/wiki/images/DependecyGraphHelloWorld.png)