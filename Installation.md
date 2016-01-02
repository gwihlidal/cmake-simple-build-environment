### Prerequisites ###

  1. install [CMake](http://www.cmake.org/cmake/resources/software.html) at least version 2.8.10.
    * If you want to use Texas Instruments compiler then version 2.8.11 is needed.
    * Even if you use version 2.8.11, coverity for Texas Instruments compiler will not work correctly because at least coverity client in version 4.5.0 doesn't understand compiler long name switches (e.g. `--cpp_file`). The switches are defined in CMake in file `CMAKE_INSTALLATION_DIRECTORY/Modules/Compiler/TI-*.cmake`. In CMake version that I use, I manually change long name switches to its short names.
  1. svn command line client has to be installed ([For windows](http://www.sliksvn.com/en/download))
  1. sed utility has to installed ([For windows](http://sourceforge.net/projects/gnuwin32/files/sed/))
  1. java has to be installed ([plantuml](http://plantuml.sourceforge.net/) delivered in Simple Build Environment uses java)

### Installation ###

  1. open shell
    * On Linux use your favorite shell
    * On windows use `Visual Studio 20xx Command Prompt`
  1. checkout Simple Build Enviroment
    * `svn checkout http://cmake-simple-build-environment.googlecode.com/svn/trunk/ cmake-simple-build-environment-read-only`
  1. install checkouted sources
    * `cd cmake-simple-build-environment-read-only`
    * `mkdir build`
    * `cd build`
    * use make to install
      * On linux
        * `cmake ..`
        * `sudo make install`
      * On windows
        * `cmake -G "NMake Makefiles" ..`
        * `nmake install`

Simple Build system is installed into CMake installation. (e.g on linux default path can be `/usr/local/share/cmake-2.8/Modules/SBE/`).