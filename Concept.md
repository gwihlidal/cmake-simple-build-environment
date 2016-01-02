# Simple Build Environment concept #

The project provides CMake scripts usable in CMakeLists.txt of CPP package.

Simple Build Environment works with following CPP packages:
  * Library (e.g. [DocumentLibrary](https://code.google.com/p/sbe-documentlibrary))
  * Executable (e.g. [HelloWorld](https://code.google.com/p/sbe-helloworld))
  * Unit Test Framework (e.g. [CppUTest](https://code.google.com/p/sbe-cpputestlibrary))
  * Project - group of Libraries/Executables (e.g. [DocumentationSystem](https://code.google.com/p/sbe-documentationsystem))

The scripts support
  * Dependency management
  * Build
  * Unit testing
  * Continuous Integration
  * Coverity

## Dependency management ##

Each package has file `Properties.cmake` in same directory as `CMakeLists.txt`. The file contains package description (e.g. [Properties.cmake for DocumentLibrary](https://code.google.com/p/sbe-documentlibrary/source/browse/trunk/Properties.cmake)).
  * `NAME` - package name
  * `TYPE` - one of _Unit Test Framework, Project_
  * `VERSION_MAJOR`, `VERSION_MINOR`, `VERSION_PATCH` - should be [semantic version](http://semver.org).
  * `DESCRIPTION` - brief description
  * `MAINTAINER` - maintainer email address
  * `DEPENDENCIES` - contains description of each dependency used by package.


Each dependency has to have goals `install` and `uninstall`. During installation, dependency has to export its targets. The scripts [AddInstallTarget.cmake](https://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/AddInstallTarget.cmake), [AddUninstallTarget.cmake](https://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/AddUninstallTarget.cmake) do this work. It is enough to include them into CMakeLists.txt file (See [DocumentLibrary CMakeLists.txt](http://code.google.com/p/sbe-documentlibrary/source/browse/trunk/CMakeLists.txt)) The export file is then used in `FIND_PACKAGE` during configuration of dependent package.

Package dependencies are described in variable `DEPENDENCIES`. Each dependency has to start with keyword `DEPENDENCY`. Each dependency can be described with:
  * `URL` - It is mandatory.
    * It is repository location of dependency release.
  * `SCM` - It is optional.
    * It is repository type. If no `SCM` keyword is given then default repository `svn` is used. Available types are:
      * svn
  * `EXTERNAL` - It is optional.
    * Meaning of the flag is that dependency marked as external
      * is not included in `package` target (see [AddPackageTarget.cmake](http://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/AddPackageTarget.cmake))
      * is not automatically updated to its latest releases
    * When dependency is marked as `EXTERNAL` then all its dependencies are external too. External dependencies have black border and External Stereotype in dependency graph.
> > ![![](http://cmake-simple-build-environment.googlecode.com/svn/wiki/images/DependecyGraphExternalSmall.png)](http://cmake-simple-build-environment.googlecode.com/svn/wiki/images/DependecyGraphExternal.png)

Example:
```cmake

set(DEPENDENCIES
DEPENDENCY
URL http://sbe-printerlibrary.googlecode.com/svn/tags/rel_1_0_0
SCM svn
EXTERNAL
DEPENDENCY
URL http://sbe-documentlibrary.googlecode.com/svn/tags/rel_1_0_0
)
```

### How it works ###

In your package CMakeLists.txt you have to include [DeployDependencies.cmake](https://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/DeployDependencies.cmake) (e.g. [CMakeLists.txt for DocumentLibrary](https://code.google.com/p/sbe-documentlibrary/source/browse/trunk/CMakeLists.txt))

The script performs two steps
  * Exports sources (it uses [ExportDependencies.cmake](https://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/ExportDependencies.cmake))
  * Install sources (it uses [InstallDependencies.cmake](https://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/InstallDependencies.cmake))

During package configuration all dependencies are exported recursively and installed.
Installation is necessary during package configuration, because include paths and libraries created by dependency are discovered by `FIND_PACKAGE`.

When dependencies are changed, their sources are deleted and uninstalled.

#### Export Sources ####

The script [ExportDependencies.cmake](https://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/ExportDependencies.cmake) uses `DEPENDENCIES` property defined in CMakeLists.txt to get all dependencies URL in repository.

It exports Properties.cmake recursively for each dependency and generates file `dependencies/info/info.cmake` in package. The file contains all properties from all dependencies.

Once all properties from all dependencies are exported, scripts performs
  1. make dependency picture - it uses [plantuml](http://plantuml.sourceforge.net/)
  1. check dependencies versions and report error if any - now exact version has to be used
> > ![![](http://cmake-simple-build-environment.googlecode.com/svn/wiki/images/DependecyGraphVersionMismatchSmall.png)](http://cmake-simple-build-environment.googlecode.com/svn/wiki/images/DependecyGraphVersionMismatch.png)
  1. check dependencies installation order and report error if any
  1. remove unused dependencies
  1. exports dependencies sources

Once sources are exported file [dependencies/info/info.cmake](http://cmake-simple-build-environment.googlecode.com/svn/wiki/snippets/info.cmake) is created and following variables are set by script [ExportDependencies.cmake](https://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/ExportDependencies.cmake):
  * `DEP_SOURCES_PATH` - path where all dependencies are exported
  * `DEP_INFO_FILE` - full name of info.cmake file

There are information about each dependency used by package in `DEP_INFO_FILE`. The file can be included into CMakeLists.txt to access dependencies properties. Following variables are available:
  * `OverallDependencies` - it is list of **all** dependencies identifiers used by package
  * `DEP_INSTALLATION_ORDER` - it is list of dependencies identifiers in order to be installed. It is used by script [InstallDependencies.cmake](https://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/InstallDependencies.cmake)
  * `EXTERNAL_DEPENDENCIES` -  - it is list of dependencies identifiers that are marked as `EXTERNAL` in package
  * For each _dependency_ in `OverallDependencies` list following properties are defined
    * `${`_`dependency`_`}_Name` - name of dependency
    * `${`_`dependency`_`}_Type` - type of dependency
    * `${`_`dependency`_`}_Version` - string version in format major.minor.patch
    * `${`_`dependency`_`}_ScmPath` - URL to repository location
    * `${`_`dependency`_`}_ScmType` - repository type
    * `${`_`dependency`_`}_DependenciesDescription` - it is list same as `DEPENDENCIES` in dependency Properties.cmake file
    * `${`_`dependency`_`}_Dependencies` - it is list of dependencies identifiers
    * `${`_`dependency`_`}_IsExternal` - set to "yes" if dependency is marked as `EXTERNAL`, otherwise it is unset.

All this variables are later used in next configuration steps.

#### Install sources ####

The script [InstallDependencies.cmake](https://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/InstallDependencies.cmake) uses `dependencies/info/info.cmake` prepared by [ExportDependencies.cmake](https://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/ExportDependencies.cmake).

The scripts performs:
  1. creates build directory `current_project_build_directory/dependencies/build/dependency_name`
  1. configure dependency in created build directory. `CMAKE_TOOLCHAIN_FILE` and `CMAKE_BUILD_TYPE` are propagated to dependency.
  1. install dependency via command `make install`. If coverity is requested, `cov_build` is performed. Once dependency is installed, dependent package can use `FIND_PACKAGE` to get information about dependency.

Once sources are installed following variables are set by script [InstallDependencies.cmake](https://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/InstallDependencies.cmake):
  * `DEP_INSTALL_PATH` - path where all dependencies are installed

## Binary Targets ##

Once dependencies are installed, dependencies properties can be used to defined own package targets.

Simple Build Environment contains script [AddBinaryTargets.cmake](http://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/AddBinaryTargets.cmake) that do it in following way.

It provides function
  * `sbeAddLibrary` - it creates library target and link this library to libraries described by own dependencies.
    * `Name` - name of target
    * `PublicHeaders` - list of public headers of library that has to be installed
    * `Sources` - list of sources to be linked
    * `Objects` - list of Object libraries to be linked
    * `FromDependency xxx LinkOnly yyy zzz` - where `xxx` is dependency name and `yyy`,`zzz` are libraries names of libraries to be linked
    * `ContainsDeclspec` - flag if public header files contains declspec.
    * `Static` - flag to create static library, otherwise shard library is created if target system supports them
    * `ExcludeDependencies` - list of dependencies that are not link to given library
> > Required argument are
      * `Name`
      * one of `Sources`/`Objects`
  * `sbeAddMockLibrary` - it creates mock library for unit testing. It is always static.
    * `Name` - name of target, usually the name is in format Mock + name of mocked library
    * `MockedName` - name of library that is mocked by this library
    * `PublicHeaders` - list of public headers of library that has to be installed
    * `Sources` - list of sources to be linked
    * `Objects` - list of Object libraries to be linked
    * `FromDependency xxx LinkOnly yyy zzz` - where `xxx` is dependency name and `yyy`,`zzz` are libraries names of libraries to be linked
    * `ContainsDeclspec` - flag if public header files contains declspec.
    * `Static` - flag to create static library, otherwise shard library is created if target system supports them
    * `ExcludeDependencies` - list of dependencies that are not link to given library
> > Required argument are
      * `Name`
      * one of `Sources`/`Objects`
  * `sbeAddExecutable` - it creates executable target and link this library to libraries described by own dependencies.
    * `Name` - name of target
    * `Sources` - list of sources to be linked
    * `Objects` - list of Object libraries to be linked
    * `FromDependency xxx LinkOnly yyy zzz` - where `xxx` is dependency name and `yyy`,`zzz` are libraries names of libraries to be linked
    * `ExcludeDependencies` - list of dependencies that are not link to given library
    * `LinkOwnLibraries` - list of libraries created by current list file
> > > Required argument are
        * `Name`
        * one of `Sources`/`Objects`
  * `sbeAddTestExecutable` - it creates test executable target and link this library to libraries described by own dependencies. I creates also main file suitable for CppUTest framework from template [template](http://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/templates/CppUTestRunAllTests.cpp.in).
    * `Name` - name of target, usually name of package + Test
    * `Sources` - list of sources to be linked
    * `Objects` - list of Object libraries to be linked
    * `FromDependency xxx LinkOnly yyy zzz` - where `xxx` is dependency name and `yyy`,`zzz` are libraries names of libraries to be linked
    * `ExcludeDependencies` - list of dependencies that are not link to given library
    * `LinkOwnLibraries` - list of libraries created by current list file

> > Required argument are
      * `Name`
  * `sbeAddObjects` - it creates Object library from sources. It is usefull to compile sources only ones and use it for creation of production executable and test executable.
    * `Name` - name of target
    * `Sources` - list of sources to be linked
    * `ContainsDeclspec` - flag if public header files contains declspec.
> > Required argument are
      * `Name`
      * `Sources`

See [DocumentLibrary CMakeLists.txt](http://code.google.com/p/sbe-documentlibrary/source/browse/trunk/CMakeLists.txt).

When added target or its dependencies contains declspec it adds defines `__EXPORT` and `__IMPORT` in compilation switches. Following compilers are supported:
  * MSVC - it sets `-D__EXPORT=__declspec(dllexport) -D__IMPORT=__declspec(dllimport)`
  * other - it sets `-D__EXPORT= -D__IMPORT=`

If it is not suitable for you, you can write your own targets and use variables defined during dependencies deployment and Properties.cmake file of your package.

For example:

It is possible to use script [AddDependenciesToTarget.cmake](https://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/helpers/AddDependenciesToTarget.cmake)

```cmake

include(SBE/helpers/AddDependenciesToTarget)

sbeAddDependencies(
Target "SomeName"
DependencyTypesToAdd "Library;Project;Unit Test Framework"
FromDependency xxx LinkOnly yyy zzz
FromDependency aaa LinkOnly bbb)
```

Or do it "low level" with `FIND_PACKAGE`

```cmake

# Get information about all dependencies
include(${DEP_INFO_FILE})
# link all dependent libraries
foreach(dep ${OwnDependenciesIds})
# Get name of dependency to find package by its name
set(depName ${${dep}_Name})
# Find dependency as package as usual in CMake
find_package(${depName} REQUIRED CONFIG PATHS ${DEP_INSTALL_PATH}/config NO_DEFAULT_PATH)
# Once package is found Include directories and package Libraries are defined. We can use them.
if(DEFINED ${depName}_INCLUDE_DIRS)
include_directories(${${depName}_INCLUDE_DIRS})
endif()
if(DEFINED ${depName}_LIBRARIES)
# link all exported
target_link_libraries(${PROJECT_NAME} ${${depName}_LIBRARIES})
endif()
endforeach()
```

## Install Target ##

#### Install Simple Build Environment package ####

Simple Build Environment provides script [AddInstalTarget.cmake](https://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/AddInstalTarget.cmake) with function `addInstallTarget` to install previously defined targets.

Function `addInstallTarget` arguments:
  * `Package` - name of package
  * `Targets` - targets to add
  * `Headers` - list of additional headers, that are not assigned as `PublicHeaders` of libraries
  * `Files` - list of files to be installed, e.g some config files\resources\...
  * `IncludePathReplacement` - regxep replacements expression to change headers paths directories during installations. The syntax is `"regexp to match include path given in `sbeAddLibrary`\`sbeAddMockLibrary`" -> "include path in installation"`
  * `FilePathReplacement` - regxep replacements expression to change paths of given files during installations. The syntax is `"regexp to match file path given in `Files`" -> "file path in installation"`

> Required argument are
    * `Package`
    * `Targets` at least one target has to be defined

See [DocumentLibrary CMakeLists.txt](https://code.google.com/p/sbe-documentlibrary/source/browse/trunk/CMakeLists.txt)

Function does:
  * installs test targets only in configuration `Debug` and `DebugWithCoverage` to directory `bin`
  * installs executables directory `bin`
  * installs libraries in directory `lib`. On Windows `dll` are installed in directory `bin`
  * installs headers files listed in `sbeAddLibrary`\`sbeAddMockLibrary` as `PublicHeaders` and change theirs include paths according to `IncludePathReplacement`.
  * creates Mock libraries for production libraries that are not explicitly mocked by `sbeAddMockLibrary` to separate test and production build. When Mock library is not explicitly created, Simple Build Environment re-link all objects of production library into static library with name Mock+Name\_Of\_Production\_Library.
  * installs mock libraries in directory lib/mock
  * when installed target contains declspec it replace all keyword `__EXPORT` with `__IMPORT` during header files installation.
  * install Config.cmake file for package.

Config.cmake file has following variables:
  * `PackageName_LIBRARIES` - list of libraries
  * `PackageName_INCLUDE_DIRS` - list of include directories
  * `PackageName_MOCK_LIBRARIES` - list of mocked libraries
  * `PackageName_MOCK_INCLUDE_DIRS` - list of mock include directories
  * `PackageName_EXECUTABLES` - list of executables
  * `PackageName_EXECUTABLES_PATH` - path where executables are located
  * `PackageName_TEST_EXECUTABLES` - list of test executables
  * `PackageName_TEST_EXECUTABLES_PATH` - path where test executables are located
  * `PackageName_CONTAINS_DECLSPEC` - flag if installed headers contains declspec

#### Install external tar.gz file ####

Will be added soon.

## Unit Tests ##

Simple Build Environment uses [CppUTest](http://cpputest.github.io)  as unit test framework. It is simply, easy to use and cross-compilable. See repository of project [CppUTestLibrary](http://code.google.com/p/sbe-cpputestlibrary/) how I integrate CppUTest into Simple Build Environment.

Simple Build Environment contains script [AddTestTargets.cmake](http://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/AddTestTargets.cmake) that creates test target for package.

The script provide function `addTestTarget`. it has argument `Executable name`, where `name` is name of test executable previously created by function `sbeAddTestExecutable`. Function `addTestTarget`
  1. adds `test` target that makes test executable and it runs tests (`make test`). In case of cross-compiling it doesn't run test executable but it prints message _Not possible to run test because of cross-compiling_.
  1. options for CppUTest executable can be added by environment variable CPPUTEST\_FLAGS (`make test CPPUTEST_FLAGS=-ojunit`)

See [HelloWorld CMakeLists.txt](http://code.google.com/p/sbe-helloworld/source/browse/trunk/CMakeLists.txt).

#### Separated Production and Test builds ####

Simple Build Environment separates production and test builds.
  * Production Targets uses dependencies headers only from `PackageName_INCLUDE_DIRS` and libraries to link with only from `PackageName_LIBRARIES`.
  * Tests Targets (executable and mock libraries) uses dependencies headers only from `PackageName_MOCK_INCLUDE_DIRS` and libraries to link with only from `PackageName_MOCK_LIBRARIES`. There can be path to production headers in `PackageName_MOCK_INCLUDE_DIRS`.

Separation is possible even if package doesn't define mock libraries explicitly.
Simple Build Environment creates creates mocked versions of libraries for production libraries that are not explicitly mocked by `sbeAddMockLibrary` to separate test and production build. When Mock library is not explicitly created, Simple Build Environment re-link all objects of production library into static library with name Mock+Name\_Of\_Production\_Library.

![![](http://cmake-simple-build-environment.googlecode.com/svn/wiki/images/PTSeparationSmall.png)](http://cmake-simple-build-environment.googlecode.com/svn/wiki/images/PTSeparation.png)

## Coverity ##

Simple Build Environment supports [Coverity](http://www.coverity.com). Simply include script [AddCoverityTargets.cmake](http://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/AddCoverityTargets.cmake) **before** script [DeployDependencies.cmake](http://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/DeployDependencies.cmake) to get coverity results.

  * It configures coverity in directory `${CMAKE_CURRENT_BINARY_DIR}/coverity`. Following compilers are supported:
    * GNU
    * Texas instruments
      * Even if you use CMake version 2.8.11 where TI compilers are suported, coverity for TI compiler will not work correctly, because at least coverity client in version 4.5.0 doesn't understand compiler's long name switches (e.g. --cpp\_file). The switches are defined in CMake in file `CMAKE_INSTALLATION_DIRECTORY/Modules/Compiler/TI-\*.cmake`. In CMake version that I use, I manually change long name switches to its short names.
  * Once Coverity is configured dependencies are build under `cov-build` command.
  * It creates target `coverity` that performs steps:
    * `cov-build make` this creates coverity data to analyze for package (data for dependencies are already created during dependencies installation)
    * `cov-analyze`
    * `cov-format-errors`

See [HelloWorld CMakeLists.txt](http://code.google.com/p/sbe-helloworld/source/browse/trunk/CMakeLists.txt).

## Tagging sources ##

Will be added soon.

See [AddTagTarget.cmake](http://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/AddTagTarget.cmake).

## Packaging Sources ##

Will be added soon.

See [AddPackageTarget.cmake](http://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/scripts/AddPackageTarget.cmake).


## Continuous Integration ##

I use [Jenkins](http://jenkins-ci.org) as continuous integration server.

#### Package integration ####

It is simple, basic scenario. It is necessary to check if package is compilable and unit test passes when more developers works on same package. It is done easily. A few plugin and tools are used in example
  * For unit testing
    * [Cobertura](https://wiki.jenkins-ci.org/display/JENKINS/Cobertura+Plugin) - visualize test coverage. I use [gcovr](https://software.sandia.gov/trac/fast/wiki/gcovr) to get coverage report compatible with Cobertura from GNU tools. Sources has to be compiled and linked with options `-fprofile-arcs -ftest-coverage -pg` (see [GnuFlags.cmake](http://code.google.com/p/sbe-toolchains/source/browse/trunk/toolchains/GnuFlags.cmake))
  * [Warnings plugin](https://wiki.jenkins-ci.org/display/JENKINS/Warnings+Plugin) - get have information about warnings trend

See [Jenkins HelloWorld Job Configuration](http://cmake-simple-build-environment.googlecode.com/svn/wiki/images/JenkinsBasic.png).

#### Multiple Configuration Package integration ####

It is sometime necessary to build package for various architectures. I use multi-configuration project for that.

There are names of toolchain files in row.
There names of build types in column.

There is one special combination [all,export]. This combination is executed first and it export package sources. Script `sbeExportDependencies` is used for that. Script is installed during Simple Build Environment installation from [template](http://code.google.com/p/cmake-simple-build-environment/source/browse/trunk/shellScripts/sbeExportDependencies.in).
Once sources are exported, given combinations can be executed in parallel. When combination is configured, CMake doesn't exports sources due to given variable `-DDEP_SRC_DEPLOYMENT_PATH=`.

See [Jenkins HelloWorld Multi-configuration Job Configuration](http://cmake-simple-build-environment.googlecode.com/svn/wiki/images/JenkinsMultiConfiguration.png).

#### Package integration with all its latest dependencies ####

I use [Build Flow plugin](https://wiki.jenkins-ci.org/display/JENKINS/Build+Flow+Plugin).

Simple Build Environment provides script `sbeCheckNewDependencies` to check new release of dependencies for package.

Define build flow using flow DSL:
```groovy

buildWhenChanged("PrinterLibrary Release")
buildWhenChanged("DocumentLibrary Release")
buildWhenChanged("DocumentationSystem Release")
buildWhenChanged("HelloWorld Release")

import hudson.scm.*
import hudson.console.HyperlinkNote

def buildWhenChanged(jobName)
{
def hudson = hudson.model.Hudson.instance
def job = hudson.getJob(jobName)

if (isLastBuildStatusWorseAsSuccess(job))
{
build(jobName)
return
}

if (hasScmChangesFor(job))
{
build(jobName)
return
}

if (areNewSbeDependenciesAvailableFor(job))
{
build(jobName)
return
}

reportSkippedBuildFor(job)
}

def isLastBuildStatusWorseAsSuccess(job)
{
def lastBuild = job.getLastCompletedBuild()

if(lastBuild == null)
{
return true
}

if(lastBuild.result != SUCCESS)
{
return true
}

return false
}

def hasScmChangesFor(job)
{
ByteArrayOutputStream baos = new ByteArrayOutputStream()
def listener = new hudson.model.StreamBuildListener(baos)
def launcher = new hudson.Launcher.LocalLauncher(listener)
def latestBuild = job.getLastCompletedBuild()

def scmrev = job.scm.calcRevisionsFromBuild(latestBuild, launcher, listener)
def pollingResult = job.scm.compareRemoteRevisionWith(job, launcher, job.workspace, listener, scmrev)

return pollingResult.hasChanges()
}

def areNewSbeDependenciesAvailableFor(job)
{
if (job.scm.locations.size() > 0)
{
remoteLocation = job.scm.locations[0].remote

def checkProcess = "sbeCheckNewDependencies $remoteLocation".execute(null, new File("/tmp"))
def sout = new StringBuffer()
def serr = new StringBuffer()
checkProcess .consumeProcessOutput(sout, serr)
checkProcess.waitFor()

return ! sout.find(/No new releases/)
}

return false
}

def reportSkippedBuildFor(job)
{
def jobHyperlinkName = HyperlinkNote.encodeTo('/' + job.url, job.fullDisplayName)
def latestBuildHyperlinkName =  HyperlinkNote.encodeTo('/' +job.getLastCompletedBuild().url, job.getLastCompletedBuild().fullDisplayName)

println "Build is not required for job " + jobHyperlinkName  + ". Sources tagged in latest completed build " + latestBuildHyperlinkName + " are used in flow."
}
```