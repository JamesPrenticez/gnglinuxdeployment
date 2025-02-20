
#!/bin/bash
# Google Automator
#




using_git_first_time()
{
	cd ~/loaner
	gbUrl=$1
	email=$2
	git config --global user.name "GNG Deployment"
	git config --global user.email email
	git init
	git add .
	git commit -m "Checking if flip worked"
	git remote add origin "$gbUrl"
	git push -u origin master
}

using_git_second_time()
{
	cd ~/loaner
	gbUrl=$1
	email=$2
	git config --global user.name "GNG Deployment"
	git config --global user.email email
	git add .
	git commit -m "Updating"
	git push -u origin master
}

Remove_LEAVE_AND_TRAIL_SPACE()
{
	local STRINGTOCHANGE=$1
	STRING_CHANGED="$(echo -e "${STRINGTOCHANGE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
	echo -e "${STRING_CHANGED}"
}

DEPLOY_SCRIPT()
{
	#!/bin/bash
	#
	# Grab n Go Loaner deployment script.

	# Include guard to prevent this script from being imported more than once.
	echo "Variables $1 $2 $3"
    sleep 5

	set -e

	# Everything between the '#' blocks is configurable by individual
	# implementers. The rest is configured to work with the existing python
	# deployment implementation.
	##############################################################################
	# Set to false if you want to skip the binary checks.
	BINARY_CHECK=true

	# Set to false if you want to skip the gcloud auth check.
	GCLOUD_AUTH_CHECK=true

	# Deployment environments; set these to your Google Cloud Project ID's.
	# These should take the format of type=project where name is the second
	# argument passed during invocation and project is the Google Cloud Project
	# ID to deploy to.
	# e.g. "dev=loaner-dev" and "prod=loaner."
	# NOTE: LOCAL does not need to be changed, it is prepared for you.
	LOCAL="local=dev"
	DEV="dev=loaner-dev"
	QA="qa=loaner-qa"
	PROD="prod=$3"

	# The app server definitions in a comma separated list.
	# NOTE: All of the deployment environments defined above need to be in this
	# list, should you remove one from above so should you remove it from here.
	readonly APP_SERVERS="${LOCAL},${DEV},${QA},${PROD}"

	# The app engine services to deploy as configured by the following yaml files.
	# The defaults are: "app.yaml,endpoints.yaml,chrome.yaml,action_system.yaml"
	readonly SERVICES="app.yaml,endpoints.yaml,chrome.yaml,action_system.yaml"

	# App Engine configuration files.
	readonly CONFIGS="cron.yaml,index.yaml,queue.yaml"

	# The web_app directory relative to the Bazel WORKSPACE.
	# The default is: "loaner/web_app"
	readonly WEB_APP_DIR="loaner/web_app"

	# The chrome_app directory relative to the Bazel WORKSPACE.
	# The default is: "loaner/chrome_app"
	readonly CHROME_APP_DIR="loaner/chrome_app"

	# The BUILD target defined in the loaner_appengine_binary BUILD rule found in
	# the web_app directory BUILD file.
	# The default is: "runfiles"
	readonly BUILD_TARGET="runfiles"
	##############################################################################

	# Color definitions for messages.
	readonly _RED="\x1B[31m"
	readonly _GREEN="\x1B[32m"
	readonly _RESET="\x1B[0m"

	# Platform definitions.
	readonly _LINUX="Linux"
	readonly _MAC="Mac"

	# Displays an error message and exits.
	# @param {string} the error message to display before exit.
	function error_message() {
	[[ -z "${1}" ]] && echo "error_message requires one argument."
	echo -e "${_RED}ERROR:${_RESET} ${1}"
	exit 1
	}

	# Displays an info message.
	# @param {string} the info message to display.
	function info_message() {
	[[ -z "${1}" ]] && error_message "info_message requires one argument."
	echo -e "${_GREEN}INFO:${_RESET} ${1}"
	}

	# Displays an success message.
	# @param {string} the success message to display.
	function success_message() {
	[[ -z "${1}" ]] && error_message "success_message requires one argument."
	echo -e "${_GREEN}SUCCESS:${_RESET} ${1}"
	}

	# Sets the platform for the machine this is running on.
	function platform() {
	UNAME="$(uname -s)"
	case "${UNAME}" in
	  Linux*) PLATFORM="${_LINUX}";;
	  Darwin*) PLATFORM="${_MAC}";;
	  *) error_message "This platform is not recognized";;
	esac
	}

	# Checks whether or not a binary is present in PATH.
	# @param {string} the binary to check.
	# @param {string} error message to display.
	function check_binary() {
	[[ -z "${1}" ]] && error_message "check_binary requires a binary to check"
	[[ -z "${2}" ]] && error_message "check_binary requires an error \
	message to display during failure"
	command -v "${1}" > /dev/null 2>&1 || \
	  error_message "${1} not found on PATH, ${2}"
	}

	# Checks that gcloud is in PATH and at or above the minimum version.
	function check_gcloud() {
	info_message "Checking for gcloud on PATH and version..."
	check_binary "gcloud" "please install the gcloud sdk to continue, more \
	info can be found here: https://cloud.google.com/sdk/downloads"
	case "${PLATFORM}" in
	  "${_LINUX}")
	    GCLOUD_VERSION=$(gcloud version \
	      | head -n 1 \
	      | cut -d ' ' -f4 \
	      | sed 's/\(^0*\|\.\)//g');;
	  "${_MAC}")
	    GCLOUD_VERSION=$(gcloud version \
	      | head -n 1 \
	      | cut -d ' ' -f4 \
	      | sed -E 's/(^0*|\.)//g');;
	esac
	[[ "${GCLOUD_VERSION}" -ge "18600" ]] || error_message "The gcloud \
	version installed is lower than the minimum required version (186.0.0), \
	please update gcloud."
	success_message "gcloud was found on PATH and is at or above the minimum \
	version."
	}

	# Checks that bazel is in PATH and at or above the minimum version.
	function check_bazel() {
	info_message "Checking for bazel on PATH and version..."
	check_binary "bazel" "please install bazel to continue, more info can be \
	found here: https://docs.bazel.build/versions/master/install.html"
	case "${PLATFORM}" in
	  "${_LINUX}")
	    BAZEL_VERSION=$(bazel version \
	      | head -n 1 \
	      | cut -d ' ' -f3 \
	      | sed 's/\(^0*\|\.\)//g');;
	  "${_MAC}")
	    BAZEL_VERSION=$(bazel version \
	      | head -n 1 \
	      | cut -d ' ' -f3 \
	      | sed -E 's/(^0*|\.)//g');;
	esac
	[[ "${BAZEL_VERSION}" -ge "90" ]] || error_message "The bazel vesrion \
	installed is lower than the minimum required version (0.9.0), please update \
	bazel."
	success_message "bazel was found on PATH and is at or above the minimum \
	version."
	}

	# Checks that npm is in PATH and at or above the minimum version (5.5.1).
	function check_npm() {
	info_message "Checking for npm on PATH and version..."
	check_binary "npm" "please install npm to continue, more info can be \
	found here: https://www.npmjs.com/get-npm"
	case "${PLATFORM}" in
	  "${_LINUX}")
	    NPM_VERSION=$(npm -v | sed 's/\(^0*\|\.\)//g');;
	  "${_MAC}")
	    NPM_VERSION=$(npm -v | sed -E 's/(^0*|\.)//g');;
	esac
	[[ "${NPM_VERSION}" -ge "530" ]] || error_message "The npm version \
	installed is lower than the minimum version (5.3.0), please update npm."
	success_message "npm was found on PATH and is at or above the minimum \
	version."
	}

	# Check that the gcloud SDK has been configured with an authenticated account.
	function check_gcloud_auth() {
	info_message "Checking gcloud authentication..."
	[[ -n $(gcloud info --format="value(config.account)") ]] || error_message \
	"gcloud does not have an account configured, please run gcloud init or gcloud \
	auth login"
	}

	# Check that the script was executed from within th`e loaner directory and goto
	# the loaner directory. Also, make sure the bazel BUILD files exist to build
	# deploy_impl.py.
	function goto_loaner_dir() {
	info_message "Going to the loaner directory..."
	# Resolve current directory of the script and any symbolic links
	if [[ "${PLATFORM}" == "${_MAC}" ]]; then
	  local pwd=$(pwd -P)
	  case "${pwd}" in
	    */loaner/loaner)
	      ;;
	    */loaner/loaner/*)
	      cd "${pwd%%/loaner/loaner/*}/loaner/loaner"
	      ;;
	    */loaner)
	      cd "${pwd%%/loaner/*}/loaner"
	      ;;
	    */loaner/*)
	      cd "${pwd%%/loaner/*}/loaner"
	      ;;
	    *)
	      error_message "This script must be run within the loaner directory."
	      ;;
	  esac
	else
	  DEPLOY_PATH="$(dirname "$(readlink -f "${0}")")"
	  # cd to the 'loaner/loaner/' directory.
	  cd "${DEPLOY_PATH}" && cd ..
	fi


	# Make sure we are in the loaner directory.
	if [[ ${PWD##*/} != "loaner" ]]; then
	  error_message "This script must be located in the loaner/deployments \
	  directory."
	fi
	cd ~/loaner/loaner

	# Check for the WORKSPACE file and that the requisite BUILD files exist.
	if [[ ! -f ../WORKSPACE || ! -f BUILD || ! -f deployments/BUILD ]]; then
	  error_message "The Bazel BUILD files appear to be missing."
	fi
	}

	# Check that the required binaries are on PATH and above the minimum version.
	if [[ "${BINARY_CHECK}" = true ]]; then
	platform
	check_gcloud
	check_bazel
	check_npm
	else
	info_message "Skipping binary check..."
	fi

	if [[ "${GCLOUD_AUTH_CHECK}" = true ]]; then
	check_gcloud_auth
	else
	info_message "Skipping gcloud auth check..."
	fi

	goto_loaner_dir

	info_message "Initiating the build of the python deployment script..."
	bazel build //loaner/deployments:deploy_impl --incompatible_disallow_filetype=false

	../bazel-out/k8-py3-fastbuild/bin/loaner/deployments/deploy_impl \
	--loaner_path "$(pwd -P)" \
	--app_servers "${APP_SERVERS}" \
	--build_target "${BUILD_TARGET}" \
	--chrome_app_dir "${CHROME_APP_DIR}" \
	--web_app_dir "${WEB_APP_DIR}" \
	--yaml_files "${SERVICES},${CONFIGS}" \
	"${@}"



}

DEPLOY_SCRIPT2()
{
	#!/bin/bash
	#
	# Grab n Go Loaner deployment script.

	# Include guard to prevent this script from being imported more than once.
	echo "Variables $1 $2 $3"
    sleep 5

	set -e

	# Everything between the '#' blocks is configurable by individual
	# implementers. The rest is configured to work with the existing python
	# deployment implementation.
	##############################################################################
	# Set to false if you want to skip the binary checks.
	BINARY_CHECK=true

	# Set to false if you want to skip the gcloud auth check.
	GCLOUD_AUTH_CHECK=true

	# Deployment environments; set these to your Google Cloud Project ID's.
	# These should take the format of type=project where name is the second
	# argument passed during invocation and project is the Google Cloud Project
	# ID to deploy to.
	# e.g. "dev=loaner-dev" and "prod=loaner."
	# NOTE: LOCAL does not need to be changed, it is prepared for you.
	LOCAL="local=dev"
	DEV="dev=loaner-dev"
	QA="qa=loaner-qa"
	PROD="prod=$3"

	# The app server definitions in a comma separated list.
	# NOTE: All of the deployment environments defined above need to be in this
	# list, should you remove one from above so should you remove it from here.


	# Displays an error message and exits.
	# @param {string} the error message to display before exit.
	function error_message() {
	[[ -z "${1}" ]] && echo "error_message requires one argument."
	echo -e "${_RED}ERROR:${_RESET} ${1}"
	exit 1
	}

	# Displays an info message.
	# @param {string} the info message to display.
	function info_message() {
	[[ -z "${1}" ]] && error_message "info_message requires one argument."
	echo -e "${_GREEN}INFO:${_RESET} ${1}"
	}

	# Displays an success message.
	# @param {string} the success message to display.
	function success_message() {
	[[ -z "${1}" ]] && error_message "success_message requires one argument."
	echo -e "${_GREEN}SUCCESS:${_RESET} ${1}"
	}

	# Sets the platform for the machine this is running on.
	function platform() {
	UNAME="$(uname -s)"
	case "${UNAME}" in
	  Linux*) PLATFORM="${_LINUX}";;
	  Darwin*) PLATFORM="${_MAC}";;
	  *) error_message "This platform is not recognized";;
	esac
	}

	# Checks whether or not a binary is present in PATH.
	# @param {string} the binary to check.
	# @param {string} error message to display.
	function check_binary() {
	[[ -z "${1}" ]] && error_message "check_binary requires a binary to check"
	[[ -z "${2}" ]] && error_message "check_binary requires an error \
	message to display during failure"
	command -v "${1}" > /dev/null 2>&1 || \
	  error_message "${1} not found on PATH, ${2}"
	}

	# Checks that gcloud is in PATH and at or above the minimum version.
	function check_gcloud() {
	info_message "Checking for gcloud on PATH and version..."
	check_binary "gcloud" "please install the gcloud sdk to continue, more \
	info can be found here: https://cloud.google.com/sdk/downloads"
	case "${PLATFORM}" in
	  "${_LINUX}")
	    GCLOUD_VERSION=$(gcloud version \
	      | head -n 1 \
	      | cut -d ' ' -f4 \
	      | sed 's/\(^0*\|\.\)//g');;
	  "${_MAC}")
	    GCLOUD_VERSION=$(gcloud version \
	      | head -n 1 \
	      | cut -d ' ' -f4 \
	      | sed -E 's/(^0*|\.)//g');;
	esac
	[[ "${GCLOUD_VERSION}" -ge "18600" ]] || error_message "The gcloud \
	version installed is lower than the minimum required version (186.0.0), \
	please update gcloud."
	success_message "gcloud was found on PATH and is at or above the minimum \
	version."
	}

	# Checks that bazel is in PATH and at or above the minimum version.
	function check_bazel() {
	info_message "Checking for bazel on PATH and version..."
	check_binary "bazel" "please install bazel to continue, more info can be \
	found here: https://docs.bazel.build/versions/master/install.html"
	case "${PLATFORM}" in
	  "${_LINUX}")
	    BAZEL_VERSION=$(bazel version \
	      | head -n 1 \
	      | cut -d ' ' -f3 \
	      | sed 's/\(^0*\|\.\)//g');;
	  "${_MAC}")
	    BAZEL_VERSION=$(bazel version \
	      | head -n 1 \
	      | cut -d ' ' -f3 \
	      | sed -E 's/(^0*|\.)//g');;
	esac
	[[ "${BAZEL_VERSION}" -ge "90" ]] || error_message "The bazel vesrion \
	installed is lower than the minimum required version (0.9.0), please update \
	bazel."
	success_message "bazel was found on PATH and is at or above the minimum \
	version."
	}

	# Checks that npm is in PATH and at or above the minimum version (5.5.1).
	function check_npm() {
	info_message "Checking for npm on PATH and version..."
	check_binary "npm" "please install npm to continue, more info can be \
	found here: https://www.npmjs.com/get-npm"
	case "${PLATFORM}" in
	  "${_LINUX}")
	    NPM_VERSION=$(npm -v | sed 's/\(^0*\|\.\)//g');;
	  "${_MAC}")
	    NPM_VERSION=$(npm -v | sed -E 's/(^0*|\.)//g');;
	esac
	[[ "${NPM_VERSION}" -ge "530" ]] || error_message "The npm version \
	installed is lower than the minimum version (5.3.0), please update npm."
	success_message "npm was found on PATH and is at or above the minimum \
	version."
	}

	# Check that the gcloud SDK has been configured with an authenticated account.
	function check_gcloud_auth() {
	info_message "Checking gcloud authentication..."
	[[ -n $(gcloud info --format="value(config.account)") ]] || error_message \
	"gcloud does not have an account configured, please run gcloud init or gcloud \
	auth login"
	}

	# Check that the script was executed from within th`e loaner directory and goto
	# the loaner directory. Also, make sure the bazel BUILD files exist to build
	# deploy_impl.py.
	function goto_loaner_dir() {
	info_message "Going to the loaner directory..."
	# Resolve current directory of the script and any symbolic links
	if [[ "${PLATFORM}" == "${_MAC}" ]]; then
	  local pwd=$(pwd -P)
	  case "${pwd}" in
	    */loaner/loaner)
	      ;;
	    */loaner/loaner/*)
	      cd "${pwd%%/loaner/loaner/*}/loaner/loaner"
	      ;;
	    */loaner)
	      cd "${pwd%%/loaner/*}/loaner"
	      ;;
	    */loaner/*)
	      cd "${pwd%%/loaner/*}/loaner"
	      ;;
	    *)
	      error_message "This script must be run within the loaner directory."
	      ;;
	  esac
	else
	  DEPLOY_PATH="$(dirname "$(readlink -f "${0}")")"
	  # cd to the 'loaner/loaner/' directory.
	  cd "${DEPLOY_PATH}" && cd ..
	fi


	# Make sure we are in the loaner directory.
	if [[ ${PWD##*/} != "loaner" ]]; then
	  error_message "This script must be located in the loaner/deployments \
	  directory."
	fi
	cd ~/loaner/loaner

	# Check for the WORKSPACE file and that the requisite BUILD files exist.
	if [[ ! -f ../WORKSPACE || ! -f BUILD || ! -f deployments/BUILD ]]; then
	  error_message "The Bazel BUILD files appear to be missing."
	fi
	}

	# Check that the required binaries are on PATH and above the minimum version.
	if [[ "${BINARY_CHECK}" = true ]]; then
	platform
	check_gcloud
	check_bazel
	check_npm
	else
	info_message "Skipping binary check..."
	fi

	if [[ "${GCLOUD_AUTH_CHECK}" = true ]]; then
	check_gcloud_auth
	else
	info_message "Skipping gcloud auth check..."
	fi

	goto_loaner_dir

	info_message "Initiating the build of the python deployment script..."
	bazel build //loaner/deployments:deploy_impl --incompatible_disallow_filetype=false

	../bazel-out/k8-py3-fastbuild/bin/loaner/deployments/deploy_impl \
	--loaner_path "$(pwd -P)" \
	--app_servers "${APP_SERVERS}" \
	--build_target "${BUILD_TARGET}" \
	--chrome_app_dir "${CHROME_APP_DIR}" \
	--web_app_dir "${WEB_APP_DIR}" \
	--yaml_files "${SERVICES},${CONFIGS}" \
	"${@}"



}


POSITIONAL=()
projectID=""; serviceAcct=""; domainName=""; adminEmail=""; oauthID="";

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -p|--projectID)
    projectID="$2"
    shift # past argument
    shift # past value
    ;;
    -s|--serviceAccount)
    serviceAcct="$2"
    shift # past argument
    shift # past value
    ;;
    -d|--domainName)
    domainName="$2"
    shift # past argument
    shift # past value
    ;;
    -sa|--superAdmin)
    adminEmail="$2"
    shift # past argument
    shift # past value
    ;;
    -o|--oAuth)
    oauthID="$2"
    shift # past argument
    shift # past value
    ;;
    -se|--sendAsEmail)
    sea="$2"
    shift # past argument
    shift # past value
    ;;
    -sg|--adminGroup)
    sag="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [[ "$projectID" == "" || "$serviceAcct" == "" || "$domainName" == "" || "$adminEmail" == "" || "$oauthID" == "" ]]; then
  echo "Please go back and make sure you have the following switches: --projectID --serviceAcct --domainName --adminEmail --oauthID --sendAsEmail, and --adminGroup"
  exit 1
fi

sea="no-reply@$domainName"
sag="technical-admins@$domainName"
#Replacing Strings within a string
#firstString="I love Suzi and Marry"
#secondString="Sara"
#echo "${firstString/Suzi/$secondString}"
#portionToBlank=""
#read -p 'Paste Public Key here: ' ready
#echo "${ready//$portionToReplace}"
#walk user through set up.
gcloud init
arr=()
join()
{
  local IFS="$1";
  shift;
  echo "$*";

}
#Afterwards lets start collecting the information we need from user input used https://stackoverflow.com/questions/18544359/how-to-read-user-input-into-a-variable-in-bash
#Will redplace {PRODID}
#clear
echo ""
printf "\033c"


projectID=$(Remove_LEAVE_AND_TRAIL_SPACE $projectID)
serviceAcct=$(Remove_LEAVE_AND_TRAIL_SPACE $serviceAcct)
domainName=$(Remove_LEAVE_AND_TRAIL_SPACE $domainName)
adminEmail=$(Remove_LEAVE_AND_TRAIL_SPACE $adminEmail)
oauthID=$(Remove_LEAVE_AND_TRAIL_SPACE $oauthID)
sea=$(Remove_LEAVE_AND_TRAIL_SPACE $sea)
sag=$(Remove_LEAVE_AND_TRAIL_SPACE $sag)



read -p 'Do you have additional Domains?(Y/N) :' mAnswer
case "$mAnswer" in
    [yY][eE][sS]|[yY])
        arr+=("$domainName")
        while [[ "$mAnswer" == "Y" ||  "$mAnswer" == "y" ||  "$mAnswer" == "yes" ||  "$mAnswer" == "YES" ]]
        do
        read -p 'Enter Domain: ' domainName
        arr+=("$domainName")
        read -p 'Do you have another Domain?(Y/N) :' mAnswer
        done
        domainName=$(join , ${arr[@]})
        ;;
    *)

        ;;
esac

#Doman Name inserts
sed -i "s/{APP_DOMAINS}/$domainName/g" ~/gnglinuxdeployment/deployment/loaner/loaner/web_app/constants.py
#Project ID insert
sed -i "s/{PRODID}/$projectID/g" ~/gnglinuxdeployment/deployment/loaner/loaner/web_app/constants.py
sed -i "s/{PRODID}/$projectID/g" ~/gnglinuxdeployment/deployment/loaner/loaner/shared/config.ts
sed -i "s/{PRODID}/$projectID/g" ~/gnglinuxdeployment/deployment/loaner/loaner/deployments/deploy.sh
#Admin Account With privleges insert
sed -i "s/{ADMIN_EMAIL}/$adminEmail/g" ~/gnglinuxdeployment/deployment/loaner/loaner/web_app/constants.py
#Send Email As Insert
sed -i "s/{SEA}/$sea/g" ~/gnglinuxdeployment/deployment/loaner/loaner/web_app/constants.py
#Super Admin Group Email Insert
sed -i "s/{SUPERADMINS_GROUP}/$sag/g" ~/gnglinuxdeployment/deployment/loaner/loaner/web_app/constants.py
#OAuth ID Inse
sed -i "s/{OAUTH2ID}/$oauthID/g" ~/gnglinuxdeployment/deployment/loaner/loaner/web_app/constants.pyrts
sed -i "s/{OAUTH2ID}/$oauthID/g" ~/gnglinuxdeployment/deployment/loaner/loaner/shared/config.ts
#Giving initial BootStrap value true
sed -i "s/{BOOTSTRAP}/True/g" ~/gnglinuxdeployment/deployment/loaner/loaner/web_app/constants.py


if [ -e ~/client-secret.json ]
then
	echo "Coppying over to prevent. Further creation of this files. Limiit does exists"
	cp -r ~/client-secret.json gnglinuxdeployment/deployment/loaner/loaner/web_app/
else
	echo "no file."
  echo "JSON key does not exists Generating key...."
  gcloud iam service-accounts keys create ~/gnglinuxdeployment/deployment/loaner/loaner/web_app/client-secret.json --iam-account $serviceAcct
  outputR=$?
fi

printf "\033c"
sleep 1
echo "Upload Completed. Now preparring to deploy Grab n Go!...Please wait."
printf "\033c"
cp -r gnglinuxdeployment/deployment/loaner ~/
cd ~/loaner
cd ~/loaner/loaner
sudo npm install --unsafe-perm node-sass@latest
gcloud services enable appengine.googleapis.com
gcloud services enable admin.googleapis.com
#gcloud services enable console
gcloud services enable cloudbuild.googleapis.com
## COULD NOT CALL A SCRIPT WITHIN A SCRIPT AND SEND THE PERMISSIONS OVER. HAD TO CONVERT TO FUNCTIION
DEPLOY_SCRIPT web prod $projectID

#sudo bash deployments/deploy.sh web prod
cd ~/loaner/loaner
sudo npm install
sudo npm install --unsafe-perm node-sass@latest
npm run build:chromeapp:once
printf "\033c"
echo "Completed! Please refer back to the Guide for next steps. Finishing configurations and loading next prompt..."
sleep 5
read -p 'Are you ready for the next steps? ' ready

gcloud app browse --launch-browser

read -p 'Did the bootstrap complete? Press (Y)/(N) to continue ' responded
#copying and deleting client-secret before upload to cloud!
cp -r ~/gnglinuxdeployment/deployment/loaner/loaner/web_app/client-secret.json ~/
sudo rm -r ~/gnglinuxdeployment/deployment/loaner/loaner/web_app/client-secret.json
bootstrapV="BOOTSTRAP_ENABLED = True"
bootstrapF="BOOTSTRAP_ENABLED = False"
bootstrapT="BOOTSTRAP_ENABLED = True"
case "$responded" in
    [yY][eE][sS]|[yY])
        sed -i "s/$bootstrapV/$bootstrapF/g" ~/loaner/loaner/web_app/constants.py
        #DEPLOY_SCRIPT2 web prod $projectID
        ;;
    *)
		sed -i "s/$bootstrapV/$bootstrapT/g" ~/loaner/loaner/web_app/constants.py
        echo "Please refer to the Example Guid for further assitance!"
		sleep 5
		exit 1
        ;;
esac
#rename github distrubution folder for chrome.
mv ~/loaner/loaner/chrome_app/dist ~/loaner/loaner/chrome_app/chromedist
printf "\033c"
read -p 'Enter the recorded Github URL:  ' gitUrl
read -p 'Enter the recorded Github Email:  ' gitEmail
using_git_first_time $gitUrl "$gitEmail"
echo ""
echo ""
gitNumber=1
while [ $gitNumber == 1 ]
do
read -p 'Was Upload Succesful? (Y)/(N)  ' gitAnswer
case "$gitAnswer" in
    [yY][eE][sS]|[yY])
        gitNumber=0
        ;;
    *)
		echo "Try login again. Make sure repository is completely blank along with URL is properly spelled. "
		read -p 'Enter the recorded Github URL:  ' gitUrl
		read -p 'Enter the recorded Github Email:  ' gitEmail
		using_git_first_time $gitUrl "$gitEmail"
		gitNumber=1
		exit 1
        ;;
esac
done
printf "\033c"
read -p 'Have you followed the directions and ready to submit the OAUTHKEY and Public Key? ' ready
#{KEYTOREPLACE}
printf "\033c"
echo ""
read -p 'Please Paste in the OAUTH client ID KEY for Chrome App: ' cOauthId
printf "\033c"
echo ""
read -p 'Please Paste in the Public Key for Chrome App: ' chromePubKey

portionToReplace="-----BEGIN PUBLIC KEY-----"
secondPortionToReplace="-----END PUBLIC KEY-----"
chromePubKey="${chromePubKey//$portionToReplace}"
chromePubKey="${chromePubKey//$secondPortionToReplace}"

sed -i "s/{OAUTH2ID}/$cOauthId/g" ~/gnglinuxdeployment/deployment/manifest.json
sed -i "s,{KEYTOREPLACE},$chromePubKey,g" ~/gnglinuxdeployment/deployment/manifest.json
rm -r ~/loaner/loaner/chrome_app/manifest.json
cp -r ~/gnglinuxdeployment/deployment/manifest.json ~/loaner/loaner/chrome_app/manifest.json


sed -i "s,{PROD_CHROME_KEY_PASTE},$chromePubKey,g" ~/loaner/loaner/shared/config.ts
sed -i "s/{CHROMEOAUTH2ID}/$cOauthId/g" ~/loaner/loaner/web_app/constants.py
cd ~/loaner/loaner
mv ~/loaner/loaner/chrome_app/chromedist ~/loaner/loaner/chrome_app/dist

DEPLOY_SCRIPT2 web prod $projectID


printf "\033c"
read -p 'Would you like to configure the IT Department contact information now? This will be information that will be displayed in a event users are having issues using the application and need help' ContactAnswer
cd ~/loaner/loaner
case "$ContactAnswer" in
    [yY][eE][sS]|[yY])
        read -p 'Enter IT Department Phone Number ' phoneNumber
        sed -i "s/{ITPHONENUMBER}/$phoneNumber/g" ~/loaner/loaner/shared/config.ts
        read -p 'Enter IT Department Email Address ' emailaddress
        sed -i "s/{ITEMAIL}/$emailaddress/g" ~/loaner/loaner/shared/config.ts
        read -p 'Enter IT Department Website' websiteInfo
        sed -i "s,{ITWEBSITE},$websiteInfo,g" ~/loaner/loaner/shared/config.ts
        DEPLOY_SCRIPT2 chrome prod $projectID

        ;;
    *)
		sed -i "s/{ITPHONENUMBER}/555-555-5555/g" ~/loaner/loaner/shared/config.ts
		sed -i "s/{ITEMAIL}/support@$domainName/g" ~/loaner/loaner/shared/config.ts
		sed -i "s,{ITWEBSITE},$domainName.com,g" ~/loaner/loaner/shared/config.ts
		DEPLOY_SCRIPT2 chrome prod $projectID

        ;;
esac
printf "\033c"
using_git_second_time $gitUrl "$gitEmail"
echo ""
echo ""
echo 'Congratualations! If your seeing this, your last step will be to redeploy your chrome app in the Chromes Store. '
echo "Open $gitUrl in another tab to finish your deployment"



cd ~/ gnglinuxdeployment/deployment/deployment.sh "grab-n-go-239222" "114430981548311974318" "updatedgrabngo@grab-n-go-239222.iam.gserviceaccount.com" "gng-demo.com" "gngadmin@gng-demo.com" "407651661683-vj2v2gqil041at2hnobm48tmu2mbu66o.apps.googleusercontent.com" "014847-8B82D2-11EF27"
#

 gnglinuxdeployment/deployment/deployment.sh --adminEmail "gngadmin@gng-demo.com" --projectID "grab-n-go-239222" --serviceAcct "updatedgrabngo@grab-n-go-239222.iam.gserviceaccount.com" "gng-demo.com" --domainName "gngadmin@gng-demo.com" --oauthID "407651661683-vj2v2gqil041at2hnobm48tmu2mbu66o.apps.googleusercontent.com" 
