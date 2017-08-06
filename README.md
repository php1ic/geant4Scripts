# geant4Scripts

This is a collection of scripts aimed at automating the installation of [geant4](https://github.com/Geant4/geant4) onto a linux system.

The [geant collaboration](http://geant4.cern.ch/) appear to have a fairly consistent release schedule; A new version is released in December, the first patch arrives in February/March of the following year with a second patch in June/July. There is also sometimes a third or fourth patch for version N-1 after the relase of version N.

With each release, you either need to overwrite your current install (bad idea as core changes may break your simulation) or organise your system in such a way as to create parallel installs (better idea, but takes up more space) allowing easy roll back if required.

The scripts were written assuming you want to go down the parallel installs route, and save space by making all versions reference a common data directory. They automate and guarantee the following:
- The cmake build options are consistent across versions
- A common directory heirarchy is followed
- Missing data sets are automatically downloaded to the correct location

There is also the ability to create sub-installs for each version. One builds the visualisation and some X11/Qt modules that can be used to create and craft your simulation, while the other is much more stripped down with non of the GUI modules. Tests with a simple simulation showed a ~20% speed up of high statistics runs with the stripped down build. Although I have not had time to quantify how much of that is a result of the different CMAKE\\_BUILD\\_TYPE options and how much is down to the other parts that were or were not included.

The default geant4 build options and install paths used in the scripts are those that work for my scenario and usage needs, I strongly recommend that you check what values are used and read the [options on the installation webpage](https://geant4.web.cern.ch/geant4/UserDocumentation/UsersGuides/InstallationGuide/html/ch02s03.html) to tailor the script to your needs.

## [create\\_geant\\_cmake.sh](create_geant_cmake.sh)

This script creates the full cmake command, taking 3 options for the **version number**, the **build type** and the **path to the source code**. It does **NOT** run the final cmake command.

```
$ ./create_geant_cmake.sh

	ERROR:	Wrong number of arguments supplied.

	USAGE:	create_geant_cmake.sh -v <geant4 version> -s <path to source> -b <release/debug>
```

The root path of the install is set on [line 19](create_geant_cmake.sh#L19), with the default being */usr/local/share/geant4*. The data directory path is constructed from this root path on [line 21](create_geant_cmake.sh#L19) so running with the default settings would require super-user privilages to build and install.

## [run\\_geant\\_cmake.sh](run_geant_cmake.sh)

This script runs the cmake command file passed as an argument, i.e. the one created and output by [create\\_geant\\_cmake.sh](create_geant_cmake.sh). If any data sets are missing, it checks that the user has permissions to write to the directory used to store the data, then downloads and extracts any that are required.

Once this script successfully runs to completion, you are ready to build and install.
