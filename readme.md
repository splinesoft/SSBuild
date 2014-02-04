# SSBuild

A bash script that builds, codesigns, and archives your iOS app. Works great on its own or with a continuous integration tool like Jenkins.

SSBuild performs these steps:

1. Downloads and installs your distribution provisioning profiles from Apple's Developer Center
2. Installs your [Cocoapods](http://cocoapods.org)
3. Updates your app's major (marketing) and minor (build) version numbers
4. Unlocks the OS X keychain to prepare for code signing
5. Builds, codesigns, and archives your app into an IPA
6. Zips your app's .dSYM.
7. (Optional) Repeats steps 2-6 for an Adhoc (Testflight/Hockeyapp) build
8. (Optional) Archives important build artifacts -- your IPA and .dSYM -- and uploads them to Amazon S3

The fun doesn't stop there. Read on to see how to configure Jenkins for even more goodness:

* Distribute your Adhoc build IPA and .dSYM to a beta service like Testflight or Hockeyapp
* Send a push notification to your iOS devices with the ultimate outcome of all previous steps - success or failure.

SSBuild powers continuous integration, packaging, archiving, Adhoc distributions, and notifications for my app [MUDRammer - A Modern MUD Client for iPhone and iPad](https://itunes.apple.com/us/app/mudrammer-a-modern-mud-client/id597157072?mt=8).

You may have some custom build steps or requirements. SSBuild is meant to be forked - make it your own!

## Why?

Continuous integration means knowing your app is always in a releasable state. Even if you don't have functional or integration tests, and regardless whether you're an indie solo developer or a massive faceless megacorp, CI will save you hours of time. With CI, you spend less time mucking about with build tools and more time coding.

CI means clicking one button and out pops your IPA, ready to be submitted to Apple.

## Requirements

* [Cupertino](https://github.com/nomad/cupertino) downloads your provisioning profiles from Apple's developer center: `[sudo] gem install cupertino`
* [Cocoapods](http://cocoapods.org) is the Objective-C package manager. You're using pods, right? `[sudo] gem install cocoapods`
* [xcpretty](https://github.com/mneorr/XCPretty) formats Apple's `xcodebuild` output, which is exceptionally verbose, into something much more human-readable. `[sudo] gem install xcpretty`
* An active iOS developer account and an app to build
* Optional: [s3cmd](http://s3tools.org/s3cmd) for uploading build artifacts to Amazon S3.

SSBuild will attempt to install `cupertino`, `cocoapods`, and `xcpretty` with the included `Gemfile`.

## Getting Started

Make sure you have the above requirements in place. You'll need 3 things to get started:

* The `SSBuild.sh` script from this repo
* A config file for your app. Check out the sample `MyApp.config` and modify it to suit your needs.
* Location of and password to a keychain containing your codesigning certificate and private key. Chances are you already have these items in your user's main login keychain. Consider creating a new keychain file (Keychain Access -> File -> New Keychain...) that contains just your iOS certificate and private key.

Keep in mind that your `MyApp.config` file **CONTAINS SECRETS** and **SHOULD NOT BE CHECKED INTO VERSION CONTROL**.


## Building

The `SSBuild.sh` script takes just one argument: the path to your `MyApp.config` file. Here's how you might run it:

```
./SSBuild.sh "/path/to/MyApp.config"
```

## Jenkins Mastery

`SSBuild.sh` works great on its own, but it really shines when you include it in a CI tool like Jenkins.

### Test Distributions

I use the [Jenkins Testflight](https://wiki.jenkins-ci.org/display/JENKINS/Testflight+Plugin) plugin to automatically upload my Adhoc IPA and .dSYM file to Testflight after every build. I prefer this plugin over a manual upload script because the plugin can include your commit history in the testflight build notes.

### Build Status Push Notifications

My Jenkins server sends me a push notification with the result of every build. There's a few pieces involved:

* [Pushover](https://pushover.net/) is a fantastic iOS app and web service for sending push notifications to your devices.

The pushover script itself is super simple:

```
curl -s \
	-F "token=PushoverToken" \
	-F "user=Pushover-User-Or-Group" \
	-F "message=Hello world" \
	-F "url=My-Build-URL" \
	https://api.pushover.net/1/messages.json
```

Ideally we want our push notification's message to include the final result status of our build. I've wired this up through the use of two separate post-build scripts, so each build fires only one success or failure script depending on its status.

* [Hudson Post-build Task](http://wiki.hudson-ci.org/display/HUDSON/Post+build+task)
* [Jenkins Post-Build script](http://wiki.jenkins-ci.org/display/JENKINS/PostBuildScript+Plugin)

## Thanks!

`SSBuild` is a [@jhersh](https://github.com/jhersh) production -- ([electronic mail](mailto:jon@her.sh) | [@jhersh](https://twitter.com/jhersh))
