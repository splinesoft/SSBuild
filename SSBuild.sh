#!/bin/bash

#
# SSBuild - a script to build your iOS app.
# By splinesoft.net.
#

function failed
{
    echo "$1" 1>&2
    exit 1
}

function clean
{
    [ -n "$OUTPUT" ] || failed "No \$OUTPUT specified!"
    
    rm -rf "$OUTPUT"
    mkdir -p "$OUTPUT"
}

function set_app_version
{
    if [ -n "$MARKETINGVERSION" ]; then
        cd $SRCROOT
        echo "Setting Marketing Version $MARKETINGVERSION"
        /usr/bin/agvtool new-marketing-version $MARKETINGVERSION &> /dev/null || failed "Failed setting marketing version"
    fi

    if [ -n "$BUILD_NUMBER" ]; then
        cd $SRCROOT
        echo "Setting Build Version $BUILD_NUMBER"
        /usr/bin/agvtool new-version -all $BUILD_NUMBER &> /dev/null || failed "Failed setting build number"
    fi
}

function ss_unlock_keychain
{
    /usr/bin/security list-keychains -s "$BUILD_KEYCHAIN"
    /usr/bin/security default-keychain -d user -s "$BUILD_KEYCHAIN"
    /usr/bin/security unlock-keychain -p "$BUILD_KEYCHAIN_PW" "$BUILD_KEYCHAIN" || failed "Failed unlocking keychain"
}

function uuid_from_profile
{
    echo `grep -aA1 UUID "$1" | grep -o "[-A-Z0-9]\{36\}"`
}

function install_profiles
{
    # remove old profiles and download distribution profiles
    
    if [ -n "$JENKINS_PROFILES" ] && [ -n "$APPLE_UN" ] && [ -n "$APPLE_PW" ]; then
        rm -rf "$JENKINS_PROFILES"
        mkdir -p "$JENKINS_PROFILES"
        cd "$JENKINS_PROFILES"
    
        /usr/bin/ios profiles:download:all \
        --type distribution \
        -u "$APPLE_UN" \
        -p "$APPLE_PW" \
        &> /dev/null || failed "Failed Downloading Profiles"
        
        # copy provisioning profiles to user library
        
        FILES=$JENKINS_PROFILES/*.mobileprovision
        
        for file in $FILES 
        do
            PROFILE_UUID=`uuid_from_profile $file`
            
            [ -n "$PROFILE_UUID" ] || failed "No UUID found in $file"
            
            cp "$file" $HOME/Library/MobileDevice/Provisioning\ Profiles/${PROFILE_UUID}.mobileprovision || failed "Failed installing $file"
        done
    fi
}

##########
# Main build and package function.
# Call with these arguments:
# 1. Path to output directory (for CONFIGURATION_BUILD_DIR)
# 2. Defines (for GCC_PREPROCESSOR_DEFINITIONS)
# 3. Scheme (e.g. 'Release' or 'Adhoc')
# 4. Path to mobile provisioning profile 
##########
function xc_package
{
    # cocoapods
    
    cd "$SRCROOT"
    pod install --no-color || failed "Failed pod install"
    
    # set marketing and build version
    
    set_app_version
    
    # unlock keychain
    
    ss_unlock_keychain &> /dev/null || failed "Failed unlocking keychain"
    
    # Calculated paths
    
    APP_IPA="$1/$APPNAME.ipa"
    APP_APP="$1/$APPNAME.app"
    APP_DSYM="$1/$APPNAME.app.dSYM"
    APP_DSYM_ZIP="$1/$APPNAME.dSYM.zip"
    
    # xcodebuild
    
    UUID=`uuid_from_profile "$4"`
    
    xcodebuild \
    -workspace "$APPWORKSPACE" \
    -scheme "$3" \
    clean build \
    CONFIGURATION_BUILD_DIR="$1" \
    PROVISIONING_PROFILE="$UUID" \
    CODE_SIGN_IDENTITY="$CODESIGN_ID" \
    OTHER_CODE_SIGN_FLAGS="--keychain $BUILD_KEYCHAIN" \
    GCC_PREPROCESSOR_DEFINITIONS="$2" | xcpretty -s --no-utf || failed "Failed building"
    
    # IPA
    
    /usr/bin/xcrun -sdk iphoneos \
    PackageApplication $APP_APP \
    -o $APP_IPA \
    --embed "$4" || failed "Failed packaging"
    
    # ZIP dSYM
    
    /usr/bin/zip -qr "$APP_DSYM_ZIP" "$APP_DSYM"
}

set -e

[ -n "$1" ] || failed "No config file specified!"

. "$1" &> /dev/null

################
# BEFORE CI
################

# Remove output

clean &> /dev/null || failed "Failed clean"

# install distribution profiles

install_profiles &> /dev/null || failed "Failed installing profiles"

################
# RELEASE
################

if [ -n "$OUTPUT_RELEASE" ]; then     
    # BUILD RELEASE
    
    xc_package \
    "$OUTPUT_RELEASE" \
    "$RELEASE_DEFINES" \
    "$SCHEME_RELEASE" \
    "$ProvisionRelease"
else
    failed "Did you specifiy a release output location?"
fi

#####################
# TESTFLIGHT // ADHOC
#####################

if [ -n "$OUTPUT_ADHOC" ]; then
    # add testflight sdk to podfile
    cd $SRCROOT
    echo "pod 'ARAnalytics/TestFlight'" >> Podfile

    # xctool ADHOC
    
    xc_package \
    "$OUTPUT_ADHOC" \
    "$ADHOC_DEFINES" \
    "$SCHEME_ADHOC" \
    "$ProvisionAdhoc"
    
    # Testflight upload with Shenzhen
    # https://github.com/nomad/shenzhen
    
    # I use the TF plugin for Jenkins, which can include build changes.
    # Haven't been able to find an easy way to include build changes otherwise
    
    #ipa distribute:testflight \
    #-f IPA file \
    #-d dSYM.zip file \
    #-a Your api key \
    #-T Your team token \
    #-m Build notes
else
    echo "Skipping Adhoc build"
fi

##################
# RESTORE KEYCHAIN
##################

/usr/bin/security list-keychains -s ~/Library/Keychains/login.keychain
/usr/bin/security default-keychain -d user -s ~/Library/Keychains/login.keychain

#################
# S3 Archive
#################

if [ -n "$S3_BUCKET" ]; then
    s3cmd sync -r \
    --exclude '*.*' \
    --include '*.ipa' --include '*.dSYM.zip' \
    $OUTPUT \
    s3://$S3_BUCKET/$JOB_NAME/$BUILD_NUMBER/
fi
