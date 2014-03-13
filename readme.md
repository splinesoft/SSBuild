# SSBuild

[![Build Status](https://travis-ci.org/splinesoft/SSBuild.png?branch=master)](https://travis-ci.org/splinesoft/SSBuild) 

A bash script that builds, codesigns, and archives your iOS app. Works great on its own or with a continuous integration tool like Jenkins.

SSBuild performs these steps:

1. Downloads and installs your distribution provisioning profiles from Apple's Developer Center
2. Updates your app's major (marketing) and minor (build) version numbers
3. Installs your [Cocoapods](http://cocoapods.org)
4. Unlocks the OS X keychain to prepare for code signing
5. Builds, codesigns, and archives your app into an IPA
6. Zips your app's .dSYM.
7. (Optional) Repeats steps 3-6 for an Adhoc (Testflight/Hockeyapp) build
8. (Optional) Archives important build artifacts -- your IPA and .dSYM -- and uploads them to Amazon S3

The fun doesn't stop there. Read on to see how to configure Jenkins for even more goodness:

* Distribute your Adhoc build IPA and .dSYM to a beta service like Testflight or Hockeyapp
* Send a push notification to your iOS devices with the ultimate outcome of all previous steps - success or failure.

SSBuild powers continuous integration, packaging, archiving, Adhoc distributions, and notifications for my app [MUDRammer - A Modern MUD Client for iPhone and iPad](https://itunes.apple.com/us/app/mudrammer-a-modern-mud-client/id597157072?mt=8).

You may have some custom build steps or requirements. SSBuild is meant to be forked - make it your own!

## Why?

Continuous integration means knowing your app is always in a releasable state. You need not muck about with provisioning profiles, you completely sidestep codesigning hell, and you spend more time coding.

CI means clicking one button and out pops your IPA, ready to be submitted to Apple.

## Requirements

* [Cupertino](https://github.com/nomad/cupertino) downloads your provisioning profiles from Apple's developer center: `[sudo] gem install cupertino`
* [Cocoapods](http://cocoapods.org) is the Objective-C package manager. You're using pods, right? `[sudo] gem install cocoapods`
* [xcpretty](https://github.com/supermarin/xcpretty) formats Apple's `xcodebuild` output, which is exceptionally verbose, into something much more human-readable. `[sudo] gem install xcpretty`
* An active iOS developer account and an app to build
* Optional: [s3cmd](http://s3tools.org/s3cmd) uploads build artifacts to Amazon S3.

SSBuild will attempt to install `cupertino`, `cocoapods`, and `xcpretty` with the included `Gemfile`.

## Building

You'll need 3 things to get started:

1. The `SSBuild.sh` script from this repo
2. A config file for your app. Check out the sample `MyApp.config` and modify it to suit your needs. Keep in mind that your `MyApp.config` file **CONTAINS SECRETS** and **SHOULD NOT BE CHECKED INTO VERSION CONTROL**.
3. Location of and password to a keychain containing your codesigning certificate and private key. Chances are you already have these items in your user's main login keychain. Consider creating a new keychain file (Keychain Access -> File -> New Keychain...) that contains just your iOS codesigning identity and private key. Make sure to password-protect your new keychain and consider checking it into version control.

The `SSBuild.sh` script takes just one argument: the path to your `MyApp.config` file. Here's how you might run it:

```bash
./SSBuild.sh "/path/to/MyApp.config"
```

## Jenkins Mastery

`SSBuild.sh` works great on its own, but it really shines when you include it in a CI tool like Jenkins.

### Test Distributions

I use the [Jenkins Testflight](https://wiki.jenkins-ci.org/display/JENKINS/Testflight+Plugin) plugin to automatically upload my Adhoc IPA and .dSYM file to Testflight after every build. I prefer this plugin over a manual upload script because the plugin can include your commit history in the testflight build notes.

### Build Status Push Notifications

My Jenkins server sends me a push notification with the result of every build. This is powered by [Pushover](https://pushover.net/), a fantastic iOS app and web service for sending push notifications to your devices.

The pushover script itself is super simple:

```bash
curl -s \
	-F "token=PushoverToken" \
	-F "user=Pushover-User-Or-Group" \
	-F "message=$JOB_NAME $BUILD_DISPLAY_NAME succeeded." \
	-F "url=$BUILD_URL" \
	https://api.pushover.net/1/messages.json
```

Ideally we want our push notification's message to include the final result status of our build. I've wired this up through the use of two separate post-build scripts; one each for build success and failure.

* [Hudson Post-build Task](http://wiki.hudson-ci.org/display/HUDSON/Post+build+task)
* [Jenkins Post-Build script](http://wiki.jenkins-ci.org/display/JENKINS/PostBuildScript+Plugin)

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
Installing Cocoapods...
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
Installing Cocoapods...
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
Performing Post build task...

+ pushover 'MUDRammer #440 succeeded.' http://***/job/MUDRammer/440/

{"status":1,"request":"***"}
POST BUILD TASK : SUCCESS
END OF POST BUILD TASK : 0
[PostBuildScript] - Execution post build scripts.
[PostBuildScript] Build is not failure : do not execute script
Finished: SUCCESS
```
