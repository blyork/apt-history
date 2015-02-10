#!/bin/bash
: '
Extract Debian Package Changes since the last upgrade/install

Helper script to extract the changelog of a debian package. Only works
if the package changelog conforms to debian packaging conventions.

Sudo/root permissions are required to execute this script. The
script "apt-history" needs to be in the executable path e.g. in
/usr/bin

@dependency dpkg-dev
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
	# The package name might have some suffix like ":amd64" but the related subdir does not have such a suffix
	PACKAGE_SUBDIR=$(echo ${PACKAGE_NAME} | awk -F ':' '{ print $1 }')

	CHANGELOG_FILE="/usr/share/doc/${PACKAGE_SUBDIR}/changelog.gz"
	if [ ! -f $CHANGELOG_FILE ]; then
		# For more recent Linux distributions (e.g. Ubunutu 14.04) the file name might be a little different.
		CHANGELOG_FILE="/usr/share/doc/${PACKAGE_SUBDIR}/changelog.Debian.gz"
	fi

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
	if [ -z "$UPGRADE_STATUS" ]; then
		# This variant allows the user to provide a package name without a machine suffix, e.g. :amd64
		UPGRADE_STATUS=$(apt-history upgrade | grep " $PACKAGE_NAME:" | tail -n 1)
	fi

	# If not yet upgraded, find out the original install status
	if [ -z "$UPGRADE_STATUS" ]; then
		INSTALL_STATUS=$(apt-history install | grep " $PACKAGE_NAME " | tail -n 1)
		if [ -z "$INSTALL_STATUS" ]; then
			# This variant allows the user to provide a package name without a machine suffix, e.g. :amd64
			INSTALL_STATUS=$(apt-history install | grep " $PACKAGE_NAME:" | tail -n 1)
		fi
		if [ -z "$INSTALL_STATUS" ]; then
			# The package was installed too long ago without any upgrade since then.
			# As the dpkg log is typically a rotating log (e.g. 12 cycles) we probably have meanwhile lost the line with the initially installed version.
			echo "Package install entry no longer available in log files" && exit 1
		fi

		# Find the installed version
		INSTALLED_VERSION=`echo ${INSTALL_STATUS} | awk -F ' ' '{ print $6 }'`

		getPackageChanges $INSTALLED_VERSION
	else
		PREVIOUS_VERSION=`echo ${UPGRADE_STATUS} | awk -F ' ' '{ print $5 }'`
		UPGRADED_VERSION=`echo ${UPGRADE_STATUS} | awk -F ' ' '{ print $6 }'`

		getPackageChanges $PREVIOUS_VERSION $UPGRADED_VERSION
	fi
fi

# ### EOF ###
