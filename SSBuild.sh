#!/bin/bash

#
# SSBuild - a script to build your iOS app.
# https://github.com/splinesoft/SSBuild
#
# The SSBuild.sh script takes just one argument: 
# the path to your MyApp.config file. 
# Here's how you might run it:
#
# ./SSBuild.sh "/path/to/MyApp.config"
#

# Send a push notification, e.g. via Pushover
# 1st arg: message to send
# 2nd arg: URL
function notify
{
    if [ -n "$PUSHOVER_TOKEN" ] && [ -n "$PUSHOVER_RECIPIENT" ]; then
        curl -s \
        -F "token=$PUSHOVER_TOKEN" \
        -F "user=$PUSHOVER_RECIPIENT" \
        -F "message=$1" \
        -F "url=$2" \
        https://api.pushover.net/1/messages.json &> /dev/null || echo 'Failed sending push notification'
    else
        echo "Missing token or recipient - not sending push notification"
    fi
}

function failed
{
    echo ""
    echo "=> $1" 1>&2
    echo ""
    notify "$JOB_NAME $BUILD_DISPLAY_NAME failed: $1" "$BUILD_URL"
    exit 1
}

function clean
{
    [ -n "$OUTPUT" ] || failed "No \$OUTPUT specified!"
    
    rm -rf "$OUTPUT"
    mkdir -p "$OUTPUT"
}

function uuid_from_profile
{
    grep -aA1 UUID "$1" | grep -o "[-a-zA-Z0-9]\{36\}"
}

function install_profiles
{    
    (cd "$BUILDROOT" && bundle exec ios profiles:download:all \
    --type distribution \
    -u "$APPLE_UN" \
    -p "$APPLE_PW" \
    > /dev/null) || failed "Failed downloading profiles"
    
    # xcodebuild looks in the running user's library folder for
    # the provisioning profile UUID you specify at build time.
    # Downloaded profiles must be copied to that location
    # AND renamed to match the profile's UUID,
    # otherwise xcodebuild will fail to codesign.
    
    PROFILES=$BUILDROOT/*.mobileprovision*
    
    for file in $PROFILES 
    do
        PROFILE_UUID=`uuid_from_profile $file`
        
        if [ -n "$PROFILE_UUID" ]; then             
            echo "Installing profile $PROFILE_UUID"
            cp "$file" "$HOME/Library/MobileDevice/Provisioning Profiles/${PROFILE_UUID}.mobileprovision" || failed "Failed installing $file"
        else
            echo "No UUID found in $file"
        fi
    done
}

##########
# Main build and package function.
# Call with these arguments:
# 1. Path to output directory (for CONFIGURATION_BUILD_DIR)
# 2. Defines (for GCC_PREPROCESSOR_DEFINITIONS)
# 3. Scheme (e.g. 'Release' or 'Adhoc')
# 4. Name of mobile provisioning profile 
##########
function xc_package
{
    echo "Building scheme \"$3\" => $1"
    
    # Calculated paths
    
    APP_IPA="$1/$APPNAME.ipa"
    APP_APP="$1/$APPNAME.app"
    APP_DSYM="$1/$APPNAME.app.dSYM"
    APP_DSYM_ZIP="$1/$APPNAME.dSYM.zip"
    PROFILE="$BUILDROOT/$4"
    
    # Prepare UUID
    
    UUID=`uuid_from_profile "$PROFILE"`
    [ -n "$UUID" ] || failed "Failed - missing provisioning profile UUID"
    echo "Building with Provisioning Profile $UUID (${PROFILE})"
    
    # Unlock keychain
        
    echo "Unlocking keychain..."
    security unlock-keychain -p "$BUILD_KEYCHAIN_PW" "$BUILD_KEYCHAIN" || failed "Failed unlocking keychain"
    security list-keychains -d user -s "$BUILD_KEYCHAIN"
    security default-keychain -d user -s "$BUILD_KEYCHAIN"
    security set-keychain-settings -lut 7200 "$BUILD_KEYCHAIN"
    security unlock-keychain -p "$BUILD_KEYCHAIN_PW" "$BUILD_KEYCHAIN" || failed "Failed unlocking keychain"
    
    if [ "$BUILD_TOOL" == "xctool" ]; then
        
        # xctool
        
        echo "Building with xctool $(xctool -v)"
        
        xctool \
        -workspace "$APPWORKSPACE" \
        -scheme "$3" \
        clean build \
        -reporter pretty \
        CONFIGURATION_BUILD_DIR="$1" \
        PROVISIONING_PROFILE="$UUID" \
        CODE_SIGN_IDENTITY="$CODESIGN_ID" \
        OTHER_CODE_SIGN_FLAGS="--keychain $BUILD_KEYCHAIN" \
        GCC_PREPROCESSOR_DEFINITIONS="\$(inherited) $2" || failed "Failed building"
        
    else
        
        # xcodebuild
        
        XCODE_VERSION=`xcodebuild -version`
        XCODE_PATH=`xcode-select -p`
        echo "Building with $XCODE_VERSION in $XCODE_PATH"
        
        cd "$BUILDROOT" && bundle exec xcodebuild \
        -workspace "$APPWORKSPACE" \
        -scheme "$3" \
        clean build \
        CONFIGURATION_BUILD_DIR="$1" \
        PROVISIONING_PROFILE="$UUID" \
        CODE_SIGN_IDENTITY="$CODESIGN_ID" \
        OTHER_CODE_SIGN_FLAGS="--keychain $BUILD_KEYCHAIN" \
        GCC_PREPROCESSOR_DEFINITIONS="\$(inherited) $2" | xcpretty -c || failed "Failed building"
        
    fi

    # Package IPA
    
    echo "Packaging IPA..."
    xcrun -sdk iphoneos \
    PackageApplication "$APP_APP" \
    -o "$APP_IPA" \
    --embed "$PROFILE" || failed "Failed packaging"
    
    # Zip dSYM
    
    echo "Zipping .dSYM..."
    zip -qr "$APP_DSYM_ZIP" "$APP_DSYM"
        
    echo "Generating Symbols and repackaging IPA..."
    
    SYMBOLS="$(xcode-select -p)/usr/bin/symbols"
    IPA_DIR="$1/IPA_TMP"
    
    unzip -q "$APP_IPA" -d "$IPA_DIR"
    mkdir -p "$IPA_DIR/Symbols"
    
    $SYMBOLS -noTextInSOD -noDaemon -arch all \
    -symbolsPackageDir "$IPA_DIR/Symbols" \
    "$APP_APP/$APPNAME"
    
    cd "$IPA_DIR" && zip -qr "$APP_IPA" .
}

set -e
set -o pipefail

[ -n "$1" ] || failed "No config file specified!"
[ -e "$1" ] || failed "Config file \"$1\" does not exist or is unreadable."

# Location of this script
export BUILDROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. "$1" &> /dev/null

[ -n "$BUILDROOT" ] || failed "No \$BUILDROOT specified!"

echo "Building $APPNAME in $SRCROOT."

###########
# BEFORE CI
###########

echo "Installing bundle..."
cd $BUILDROOT 
bundle check --path=vendor/bundle || bundle install --jobs=4 --retry=2 --path=vendor/bundle

# Remove output

echo "Cleaning output..."
clean &> /dev/null || failed "Failed clean"

# install profiles (two attempts - Apple's Dev site can be wonky)

if [ -n "$APPLE_UN" ] && [ -n "$APPLE_PW" ]; then
    echo "Installing distribution provisioning profiles for $APPLE_UN..."
    install_profiles || failed "Failed installing profiles"
else
    echo "Skipping provisioning profile download; no apple username or password"
fi

# set marketing and build version

if [ -n "$MARKETINGVERSION" ]; then
    echo "Setting App marketing version $MARKETINGVERSION..."
    (cd "$SRCROOT" && /usr/bin/agvtool new-marketing-version $MARKETINGVERSION > /dev/null) || failed "Failed setting marketing version"
else
    echo "Skipping setting marketing version. Specify \$MARKETINGVERSION in your App.config."
fi

if [ -n "$BUILD_NUMBER" ]; then
    echo "Setting build number $BUILD_NUMBER..."
    (cd "$SRCROOT" && /usr/bin/agvtool new-version -all $BUILD_NUMBER > /dev/null) || failed "Failed setting build number"
else
    echo "Skipping setting build number. Specify \$BUILD_NUMBER."
fi

##
# Generate a changelog file containing the git commit history
# since the last successful build. 
# Requires Jenkins, which populates JOB_URL for us
##
if [ -n "$JOB_URL" ] && [ -n "$CHANGELOG_FILE" ] && [ -n "$JENKINS_USER" ] && [ -n "$JENKINS_TOKEN" ]; then
    
    LAST_SUCCESS_URL_SUFFIX="lastSuccessfulBuild/api/xml"
    BUILD_XML_URL="${JOB_URL}${LAST_SUCCESS_URL_SUFFIX}"

    # fetch the last successfully-built revision
    LAST_SUCCESS_REV=$(set -o pipefail && curl -sk --user ${JENKINS_USER}:${JENKINS_TOKEN} "$BUILD_XML_URL" | grep "<lastBuiltRevision>" | sed 's|.*<lastBuiltRevision>.*<SHA1>\(.*\)</SHA1>.*<branch>.*|\1|' || failed "Failed fetching last built revision from $BUILD_XML_URL")

    # All commit comments since the last successfully built revision
    LOG=$(cd "$SRCROOT" && git log --pretty="$CHANGELOG_FORMAT" "${LAST_SUCCESS_REV}..HEAD")
    
    echo "$LOG" > "${OUTPUT}/${CHANGELOG_FILE}"
    echo "Wrote changelog to ${OUTPUT}/${CHANGELOG_FILE}"
else
    echo "Skipping generating changelog"
fi

# cocoapods

echo "Installing pods (CocoaPods v$(bundle exec pod --version))..."
bundle exec pod install --project-directory="$SRCROOT" || failed "Failed installing CocoaPods"

###############
# BUILD RELEASE
###############

if [ -n "$RELEASE_OUTPUT" ]; then         
    xc_package \
    "$RELEASE_OUTPUT" \
    "$RELEASE_DEFINES" \
    "$RELEASE_SCHEME" \
    "$RELEASE_PROFILE"
else
    failed "Did you specify a release output location?"
fi

#############
# BUILD ADHOC
#############

if [ -n "$ADHOC_OUTPUT" ]; then
    xc_package \
    "$ADHOC_OUTPUT" \
    "$ADHOC_DEFINES" \
    "$ADHOC_SCHEME" \
    "$ADHOC_PROFILE"
else
    echo "Skipping Adhoc build"
fi

##################
# RESTORE KEYCHAIN
##################

security list-keychains -d user -s "${HOME}/Library/Keychains/login.keychain"
security default-keychain -d user -s "${HOME}/Library/Keychains/login.keychain"

###############
# NUKE PROFILES
###############

# We destroy all downloaded provisioning profiles after every build.
# Redownloading profiles for every build means that we can immediately 
# capture any changes you've made in Apple's developer center.

PROFILES=$BUILDROOT/*.mobileprovision*

echo "Removing profiles..."

for file in $PROFILES 
do
    rm $file
done

############
# S3 Archive
############

if [ -n "$S3_BUCKET" ]; then
    
    echo "Uploading to S3 bucket \"$S3_BUCKET\"..."
    
    s3cmd sync -rv --no-guess-mime-type \
    --exclude '*.*' \
    --include '*.ipa' --include '*.dSYM.zip' --include "$CHANGELOG_FILE" \
    $OUTPUT/* \
    s3://$S3_BUCKET/$JOB_NAME/$BUILD_NUMBER/
fi

########
# NOTIFY
########

# various parameters here supplied by jenkins at build time
notify "${JOB_NAME} ${BUILD_DISPLAY_NAME} (${GIT_BRANCH}@${GIT_COMMIT:0:7}) succeeded." "${BUILD_URL}"
