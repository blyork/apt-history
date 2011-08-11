#!/bin/bash
: '
Extract Debian Package Changes since the last upgrade/install

Helper script to extract the changelog of a debian package. Only works
if the package changelog conforms to debian packaging conventions.

Sudo/root permissions are required to execute this script. The
script "apt-history" needs to be in the executable path e.g. in
/usr/bin
 
@author Jeffery Fernandez <jeffery@fernandez.net.au>
@since Thu, 11 Aug 2011 10:39:08 +1000
'

PACKAGE_NAME=
if [ $# -eq 1 ]; then
	PACKAGE_NAME=$1
else
	echo "Package name is required" && exit 1
fi

getPackageChanges()
{
	CHANGELOG_FILE="/usr/share/doc/${PACKAGE_NAME}/changelog.gz"

	# If we have the changelog for the package
	if [ -f $CHANGELOG_FILE ]; then
		if [ $# -eq 1 ]; then
			zcat $CHANGELOG_FILE | dpkg-parsechangelog -l- --from "$1"
		else
			zcat $CHANGELOG_FILE | dpkg-parsechangelog -l- --from "$1" --to "$2"
		fi
	else
		echo "Missing Changelog file" && exit 1
	fi
}

IS_PACKAGE_INSTALLED=$(dpkg -s $PACKAGE_NAME 2>/dev/null) 
if [ $? -eq 1 ]; then
	echo "Package is not installed" && exit 1
else
	# Get the installed version number
	INSTALLED_VERSION=`echo "${IS_PACKAGE_INSTALLED}" | grep "^Version:" | awk -F ' ' '{ print $2 }'`
	
	# If a version was not returned, then we know it was purged
	if [ -z "$INSTALLED_VERSION" ]; then
		echo "Package is currently not installed or is purged" && exit 1
	fi
	
	# Has it been upgraded?
	UPGRADE_STATUS=$(apt-history upgrade | grep " $PACKAGE_NAME " | tail -n 1)

	# If not yet upgraded, find out the install status
	if [ -z "$UPGRADE_STATUS" ]; then
		INSTALL_STATUS=$(apt-history install | grep " $PACKAGE_NAME " | tail -n 1)

		# Find the installed version
		INSTALLED_VERSION=`echo ${INSTALL_STATUS} | awk -F ' ' '{ print $6 }'`

		getPackageChanges $INSTALLED_VERSION
	else
		PREVIOUS_VERSION=`echo ${UPGRADE_STATUS} | awk -F ' ' '{ print $5 }'`
		UPGRADED_VERSION=`echo ${UPGRADE_STATUS} | awk -F ' ' '{ print $6 }'`
		
		getPackageChanges $PREVIOUS_VERSION $UPGRADED_VERSION
	fi
fi



