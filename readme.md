# SSBuild

[![Build Status](https://travis-ci.org/splinesoft/SSBuild.png?branch=master)](https://travis-ci.org/splinesoft/SSBuild) 

A bash script that builds, codesigns, and archives your iOS app. Works great on its own or with a continuous integration tool like Jenkins.

SSBuild performs these steps:

1. Downloads and installs your distribution provisioning profiles from Apple's Developer Center
2. Updates your app's major (marketing) and minor (build) version numbers
3. Writes a changelog with the commit history since the last successful build (requires Jenkins)
4. Installs your [CocoaPods](http://cocoapods.org)
5. Unlocks the OS X keychain to prepare for code signing
6. Builds, codesigns, and archives your app into an IPA
7. Zips your app's .dSYM.
8. (Optional) Repeats steps 5-7 for an Adhoc (Testflight/Hockey/Crashlytics) build
9. (Optional) Uploads important build artifacts -- your IPA(s) and .dSYM(s) -- to Amazon S3
10. (Optional) Distributes your Adhoc build IPA and .dSYM to a beta service like Hockey or Crashlytics
11. (Optional) Sends a push notification (powered by [Pushover](https://pushover.net/)) to your iOS devices with a success or failure message.

SSBuild powers continuous integration, packaging, archiving, Adhoc distributions, and notifications for my app [MUDRammer - A Modern MUD Client for iPhone and iPad](https://itunes.apple.com/us/app/mudrammer-a-modern-mud-client/id597157072?mt=8).

You may have some custom build steps or requirements. SSBuild is meant to be forked - make it your own!

## Why?

Continuous integration means knowing your app is always in a releasable state. You need not muck about with provisioning profiles, you completely sidestep codesigning hell, and you spend more time coding.

CI means clicking one button and out pops your IPA, ready to be submitted to Apple.

## Requirements

* An active iOS developer account and an app to build
* [Cupertino](https://github.com/nomad/cupertino) downloads your provisioning profiles from Apple's developer center.
* [CocoaPods](http://cocoapods.org) is the Objective-C package manager. You're using pods, right?
* [xcpretty](https://github.com/supermarin/xcpretty) formats Apple's `xcodebuild` output, which is exceptionally verbose, into something much more human-readable.
* Optional: [s3cmd](http://s3tools.org/s3cmd) uploads build artifacts to Amazon S3.

SSBuild will attempt to install `cupertino`, `cocoapods`, and `xcpretty` with the included `Gemfile`.

## Building

You'll need 3 things to get started:

1. The `SSBuild.sh` script from this repo
2. A config file for your app. Check out the sample `MyApp.config` and modify it to suit your needs. Keep in mind that your `MyApp.config` file **CONTAINS SECRETS** and **SHOULD NOT BE CHECKED INTO VERSION CONTROL**.
3. Location of and password to a keychain containing your codesigning certificate and private key. Chances are you already have these in your user's main login keychain. Try creating a new keychain file (Keychain Access -> File -> New Keychain...) that contains only your iOS codesigning identity and private key. Make sure to password-protect your new keychain and consider checking it into version control.

The `SSBuild.sh` script takes just one argument: the path to your `MyApp.config` file. Here's how you might run it:

```bash
./SSBuild.sh "/path/to/MyApp.config"
```

## Jenkins Mastery

`SSBuild.sh` works great on its own, but it really shines when you include it in a CI tool like Jenkins.

### Test Distributions

MUDRammer's adhoc test builds are powered by [Crashlytics Beta](http://try.crashlytics.com/beta/). Jenkins automatically uploads an adhoc IPA to Crashlytics after each build:

```bash
$WORKSPACE/src/Mudrammer/Supporting*/Crashlytics.framework/submit \
AN_API_KEY \
A_BUILD_SECRET_KEY \
-ipaPath $WORKSPACE/output/adhoc/MUDRammer.ipa \
-groupAliases core \
-notesPath $WORKSPACE/output/changelog.txt \
-debug
```

## Thanks!

`SSBuild` is a [@jhersh](https://github.com/jhersh) production -- ([electronic mail](mailto:jon@her.sh) | [@jhersh](https://twitter.com/jhersh))

## Appendix: Building MUDRammer

Where were you at 3:48am PST on March 7, 2014?

It was a calm night in San Francisco... but then this happened:

```bash
Building MUDRammer in /Users/***/.jenkins/workspace/MUDRammer/src.
Installing bundle...
Cleaning output...
Installing distribution provisioning profiles for admin@splinesoft.net...
Setting App marketing version 1.7.1...
Setting build number 440...
Building scheme "MUDRammer Release" => /Users/***/.jenkins/workspace/MUDRammer/output/release
Installing CocoaPods...
Analyzing dependencies
Downloading dependencies
    *** snip ***
Generating Pods project
Integrating client project
Unlocking keychain...
Building!
	*** snip ***
▸ Signing /Users/***/.jenkins/workspace/MUDRammer/output/release/MUDRammer.app
Packaging IPA...
Zipping .dSYM...
Building scheme "MUDRammer Adhoc" => /Users/***/.jenkins/workspace/MUDRammer/output/adhoc
Installing CocoaPods...
Analyzing dependencies
Downloading dependencies
    *** snip ***
Generating Pods project
Integrating client project
Unlocking keychain...
Building!
    *** snip ***
▸ Signing /Users/***/.jenkins/workspace/MUDRammer/output/adhoc/MUDRammer.app
Packaging IPA...
Zipping .dSYM...
Removing profiles...
INFO: Compiling list of local files...
INFO: Compiling list of local files...
INFO: Retrieving list of remote files for s3://***/MUDRammer/440/ ...
INFO: Found 4 local files, 0 remote files
INFO: Applying --exclude/--include
INFO: Applying --exclude/--include
INFO: Verifying attributes...
INFO: Summary: 4 local files to upload, 0 files to remote copy, 0 remote files to delete
    *** snip ***
Done. Uploaded 33431322 bytes in 133.8 seconds, 244.01 kB/s.  Copied 0 files saving 0 bytes transfer.
[OS X] restore keychains as defined in global configuration
[MUDRammer] $ /usr/bin/security list-keychains -s /Users/***/Library/Keychains/login.keychain
[MUDRammer] $ /usr/bin/security default-keychain -d user -s /Users/***/Library/Keychains/login.keychain
Uploading to testflight
File: /Users/***/.jenkins/workspace/MUDRammer/output/adhoc/MUDRammer.ipa
DSYM: /Users/***/.jenkins/workspace/MUDRammer/output/adhoc/MUDRammer.dSYM.zip
Testflight Upload speed: 1.68Mbps
Testflight Install Link: ***
Testflight Configuration Link: ***
Finished: SUCCESS
```
