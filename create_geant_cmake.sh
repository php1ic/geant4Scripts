#!/usr/bin/env bash

#####################
#
# Script to automate the creation of the cmake command
#
# There are many arguments provided to cmake, so to keep
# consistency between versions, this script only requires:
#    - version number
#    - source code location
#    - build type
#
# The actual cmake command is not executed, but a command file
# is output which can be checked and executed.
#
#####################

#ROOT of the install location
INSTALLDIR=/usr/local/share/geant4
#Where do the datasets live
DATAPATH=${INSTALLDIR}/data

#Common options, independent of build type
BASE_TEMPLATE="-DCMAKE_INSTALL_PREFIX=INSTALLDIR/VERSION/install/BUILD_LEVEL \
-DGEANT4_INSTALL_DATADIR=DATAPATH \
-DGEANT4_BUILD_MULTITHREADED=ON "

#Options for the debug build type
DEBUG_OPTIONS="${BASE_TEMPLATE} \
-DCMAKE_BUILD_TYPE=RelWithDebInfo \
-DGEANT4_USE_QT=ON \
-DGEANT4_USE_GDML=ON \
-DGEANT4_USE_OPENGL_X11=ON \
-DGEANT4_USE_RAYTRACER_X11=ON"

#Options for the release build type
RELEASE_OPTIONS="${BASE_TEMPLATE} \
-DCMAKE_BUILD_TYPE=Release \
-DGEANT4_BUILD_STORE_TRAJECTORY=OFF \
-DGEANT4_BUILD_VERBOSE_CODE=OFF"

############################
# Don't edit below this line
############################

RESTORE="\e[0m" #N.B. This is a reset of the colour, not black
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[1;34m"
YELLOW="\e[33m"

usage() {
    echo -e "
\t${BLUE}USAGE:${RESTORE}\t${BASH_SOURCE##*/} -v <geant4 version> -s <path to source> -b <release/debug>
"
    exit 1
}

#Check user can write (i.e. build) to where we are.
#If it can't then exit as we can't go any further
if [[ ! -w ${PWD} ]]
then
    echo -e "\n\t${RED}ERROR:${RESTORE} Current user does not have permission to write here ${PWD}"
    usage
fi

#The version, source and build type are required
if [[ $# -ne 6 ]]
then
    echo -e "\n\t${RED}ERROR:${RESTORE}\tWrong number of arguments supplied."
    usage
fi

while getopts ":hv:b:s:" OPTIONS
do
    case "${OPTIONS}" in
        h | \? | : )
            usage
            ;;
        v )
            #Value is validated later in script
            VERSION=${OPTARG}
            ;;
        b )
            #Value is validated later in script
            BUILD_LEVEL=${OPTARG}
            ;;
        s )
            #Check the directory exists
            SOURCE=$(readlink -f "${OPTARG}")
            [ -d "${SOURCE}" ] || usage
            ;;
    esac
done

#Sanity check version number
#They changed the CMakeLists.txt file for 10.4 so we need a different way to extract the version
#Comparing version numbers in a general/distro agnostic way is a pain
# 1 Make a list containing the input version and the last version prior to the change
# 2 Sort this list using the inbuilt 'version comparison' flag and extract the 'highest' number
# 3 Compare this value to the last version prior to the change and act accordingly

#We are doing a string comparison so use a value higher than was ever release, but lower than the change version
MAX_OLD_VERSION="10.3.9"
CMAKEFILE=${SOURCE}/CMakeLists.txt
if [[ "$(echo -e "${VERSION}\n${MAX_OLD_VERSION}" | sort -rV | head -n1)" == "${MAX_OLD_VERSION}" ]]
then
    #echo "Pre 10.4"
    SOURCE_VERSION=$(sed -n 's/^.*_VERSION \"\(.*\)\".*$/\1/p' "${CMAKEFILE}")
else
    #echo "Post 10.4"
    SOURCE_VERSION=$(sed -n 's/^.*PROJECT_NAME._VERSION_.* \([[:digit:]]*\)).*$/\1/p' "${CMAKEFILE}" | paste -s -d '.')
fi

if [[ "${SOURCE_VERSION}" != "${VERSION}" ]]
then
    echo -e "\n\t${RED}WARNING:${RESTORE}\tThe version specified <${VERSION}> does not match that of the source code <${SOURCE_VERSION}>\n"

    while true
    do
	read -p "Do you wish to continue? [y/n]: " yn
	case $yn in
            [Yy]* )
		break
		;;
            [Nn]* )
		echo "Exiting ..."
		exit 3
		;;
            * )
		echo "Please answer yes or no."
		;;
	esac
    done
fi


#Set the cmake options
case "${BUILD_LEVEL}" in
    "debug" )
        OPTIONS_TEMPLATE="${DEBUG_OPTIONS}"
        ;;
    "release" )
        OPTIONS_TEMPLATE="${RELEASE_OPTIONS}"
        ;;
    * )
        echo -e "\n\t${RED}ERROR:${RESTORE}\t${BUILD_LEVEL} is not a valid build type, used 'release' or 'debug' \n"
        exit 4
        ;;
esac

#Arguments have been checked and validated, lets create the command.
CMAKE_TEMPLATE="cmake ${OPTIONS_TEMPLATE} SOURCE"

echo -e "
The build directory will be the current directory - ${BLUE}${PWD}${RESTORE}

Creating cmake command using the details
=========================
geant4 version         - ${GREEN}${VERSION}${RESTORE}
geant4 build type      - ${GREEN}${BUILD_LEVEL}${RESTORE}
root install directory - ${GREEN}${INSTALLDIR}/${VERSION}/install/${BUILD_LEVEL}${RESTORE}
geant4 data directory  - ${GREEN}${DATAPATH}${RESTORE}
source code directory  - ${GREEN}${SOURCE}${RESTORE}
=========================
"

#Modify template to use the real values
#Need to use '%' as the sed delimiter because
# | are read as command pipes
# / Are contained within the paths
#Final substitution squashed muliple space into a single one
echo -e "\nConstructing the following cmake command:"
MYMAKE=$(echo "${CMAKE_TEMPLATE}" | \
                sed -e s%VERSION%${VERSION}%g \
                    -e s%INSTALLDIR%${INSTALLDIR}%g \
                    -e s%DATAPATH%${DATAPATH}%g \
                    -e s%BUILD_LEVEL%${BUILD_LEVEL}%g \
                    -e s%SOURCE%${SOURCE}% \
                    -e 's% \+% %g'
      )

echo -e "${YELLOW}${MYMAKE// /\\n}${RESTORE}"

OUTFILE=${VERSION}_cmake.txt
echo -en "\nWriting the command into ${OUTFILE} ... "
echo "${MYMAKE}" > "${OUTFILE}"
chmod u+x "${OUTFILE}"
echo -e " done\n"

echo -e "The cmake command can now be run by executing: ${RED}./${OUTFILE}${RESTORE}"

#Check if current user has permissions to 'make install'
if [[ ! -w ${INSTALLDIR} ]]
then
    echo -e "\n${BLUE}INFO:${RESTORE} Current user does not have write permissions to install into ${INSTALLDIR}"
fi

echo ""
exit $?
