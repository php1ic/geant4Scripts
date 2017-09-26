#!/bin/bash

#####################
#
# Script to execute the provided cmake command and download datasets if required
#
# New versions of geant4 often come with new datasets. This script automates their
# download and extraction by running the cmake command file created by
# create_geant_cmake.sh, parsing the output and doing what's needed.
#
#####################

RESTORE="\e[0m" #N.B. This is a reset of the colour, not black
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[1;34m"
YELLOW="\e[33m"

usage() {
    echo -e "
\t${BLUE}USAGE:${RESTORE}\t${0##*/} -f <cmake command file>
"
    exit 1
}

while getopts ":hf:" OPTIONS
do
    case "${OPTIONS}" in
        h | \? | : )
            usage
            ;;
        f )
            FILE=${OPTARG}
            ;;
    esac
done

#Confirm that an input file has been provided
if [[ -z "${FILE}" ]]
then
    echo -e "\n\t${RED}ERROR:${RESTORE}\tYou need to specify the cmake command file to run"
    usage
elif [[ ! -e "${FILE}" ]]
then
    echo -e "\n\t${RED}ERROR:${RESTORE}\t${FILE} does not exist"
    usage
fi

#Capture where the data files are expected to live
DATADIR=$(sed "s/^.*INSTALL_DATADIR=\([^ ]*\).*$/\1/" ${FILE})

if [[ -z ${DATADIR} ]]
then
    echo -e "${RED}\n\tERROR:${RESTORE}\tThe data directory has not been specified, exiting...\n"
    exit 2
fi

#We'll capture the output rather than running cmake multiple times.
CMAKE_OUTPUT=cmake_output.log

#Run the cmake command that was provided
echo -e "${YELLOW}Running cmake${RESTORE}\n"

#If cmake fails, we have bigger issues than missing data
if ./${FILE} 2>&1 | tee ${CMAKE_OUTPUT}
then
    echo -e "${RED}\n\tERROR:${RESTORE}\tRunning cmake failed\n"
    exit 3
fi

#What should we look for to confirm that we are missing datasets
MISSING_STRING="the following datasets are NOT present"

#If we aren't missing any datasets, there is nothing further to do.
if [[ $(grep -c "${MISSING_STRING}" ${CMAKE_OUTPUT}) -eq 0 ]]
then
    echo -e "\n${GREEN}All went as expected.${RESTORE}\n"
    exit 4
#But if we are, make sure we can write/extract to the path specified
else
    echo -en "\n${YELLOW}Data files are missing "

    if [[ ! -w ${DATADIR} ]]
    then
        echo -e "${YELLOW}but you don't have permission to write to ${DATADIR}, exiting...\n${RESTORE}"
        exit 5
    fi

    echo -e "aquiring now.${RESTORE}\n"
fi

#Store the url(s) of the missing datasets
FILE_LIST=${DATADIR}/filesToGet.txt
#The commonly unique part of the url in the cmake output
FILE_STRING="http://geant4.cern.ch/support/source"

#Get which data files are missing.
sed -n "s|^[ \t]*\(${FILE_STRING}\)|\1|p" ${CMAKE_OUTPUT} > ${FILE_LIST}

echo -e "${YELLOW}Moving into the data directory ${DATADIR}${RESTORE}\n"
pushd "${DATADIR}" > /dev/null

echo -e "${YELLOW}Downloading and extracting the necessary files:${RESTORE}"
#We could pass the file to wget with the -i flag but we'd still have to parse
#it to extract each dataset so do it this way
while read -r LINE
do
    #echo "${LINE} |---| ${LINE##*/}"
    #We want to keep the archived files so download and extract separately
    wget -nv --show-progress ${LINE}
    #Without the 'o' flag, files extract as owned by geant developers i.e. unknown on this system
    tar xof ${LINE##*/}
done < ${FILE_LIST}

#Cleanup, delete, the file with list of missing datasets
rm -f ${FILE_LIST}

#We could do a recursive call to this script, but lets not.
#Just re-run the cmake command, everything should work now.
echo -e "\n${YELLOW}Re-running cmake now that we have the all of the datasets${RESTORE}"
popd > /dev/null
./${FILE}

#Leave the output from the original cmake execution
#rm -v ${CMAKE_OUTPUT}

exit $?
