### Goal ###

The goal of the project is to create build environment for CPP development with similar features as maven in java.

Especially easy to use for
  * transitive dependency management
    * visualization
    * compatibility check
    * downloading and installing
  * cross-compilation
  * unit testing integration
  * continuous integration
  * declspec handling

### Get in Touch ###

To get in touch read:
  1. [Concept](Concept.md)
  1. [Installation](Installation.md)
  1. [Example](Example.md)

### Related Projects ###

Because project goal is to provide build environment where one package uses other to achieve its goal projects are used to demonstrate its functionality:
  * [PrinterLibrary](http://code.google.com/p/sbe-printerlibrary/) - prints strings
  * [DocumentLibrary](http://code.google.com/p/sbe-documentlibrary/) -  generates various kinds of documents
  * [DocumentationSystem](http://code.google.com/p/sbe-documentationsystem/) - contains all libraries to use for generating documentaion
  * [CppUTest](http://code.google.com/p/sbe-cpputestlibrary/) - unit test framework
  * [HelloWorld](http://code.google.com/p/sbe-helloworld/) - application that uses test framework and libraries
  * [Toolchains](http://code.google.com/p/sbe-toolchains/) - toolchain files used mostly for cross-compilation