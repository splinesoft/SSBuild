# encoding: UTF-8

class String
  def self.colorize(text, color_code)
	"\e[#{color_code}m#{text}\e[0m"
  end

  def cyan
	self.class.colorize(self, 36)
  end

  def green
	self.class.colorize(self, 32)
  end
end

desc 'Send a push notification with a message and URL'
def notify(message, messageURL) 
	if ENV["PUSHOVER_TOKEN"] && ENV["PUSHOVER_RECIPIENT"]
		sh "curl -s "+
			"-F 'token=#{ENV["PUSHOVER_TOKEN"]}' "+
			"-F 'user=#{ENV["PUSHOVER_RECIPIENT"]} "+
			"-F 'message=#{message}' "+ \
			"-F 'url=#{messageURL}' "+ 
			"https://api.pushover.net/1/messages.json > /dev/null"
	else
		puts "Missing token or recipient - not sending push notification"
	end
end

desc 'Extracts a UUID from a provisioning profile'
def uuid_from_profile(profile)
  uuid_str = `grep UUID -A1 -a #{profile}`
  uuid = uuid_str.match(/[-a-zA-Z0-9]{36}/)[0]
  return uuid
end

desc 'Unlocks the keychain.'
def unlock_keychain(keychain_loc, password)
  puts "Unlocking Keychain...".cyan
  sh "security list-keychains -s #{keychain_loc}"
  sh "security default-keychain -d user -s #{keychain_loc}"
  sh "security unlock-keychain -p #{password} #{keychain_loc}"
  sh "security set-keychain-settings -t 3600 -l #{keychain_loc}"
end

desc 'Builds the app with specified scheme, workspace, output location, provisioning profile, code-signing identity, app name'
def build(scheme, workspace, output, profile, codesign_id, app_name)

  raise 'No Profile found?' if profile == ''

  uuid = uuid_from_profile("#{profile}")
  raise 'No UUID found?' if uuid == ''
  
  puts "Installing profile #{uuid}...".cyan
  `cp #{profile} "$HOME/Library/MobileDevice/Provisioning\ Profiles/#{uuid}.mobileprovision"`

  puts "Removing output".cyan
  `rm -r #{output}`

  xcode_version = `xcodebuild -version`.chomp
  xcode_path = `xcode-select -p`.chomp

  puts "Building with #{xcode_version} in #{xcode_path}".cyan

  sh "xctool "+
	  "-scheme '#{scheme}' "+
	  "-workspace '#{workspace}' "+
	  "-sdk iphoneos "+
	  "clean build "+
	  "CODE_SIGN_IDENTITY='#{codesign_id}' "+
	  "PROVISIONING_PROFILE='#{uuid}' "+
	  "CONFIGURATION_BUILD_DIR='#{output}'"

  puts "Packaging IPA...".cyan

  sh "/usr/bin/xcrun -sdk iphoneos "+
	"PackageApplication '#{output}/#{app_name}.app' "+
	"-o '#{output}/#{app_name}.ipa' "+
	"--sign '#{codesign_id}' "+
	"--embed '#{profile}'"

  puts "Zipping .dSYM...".cyan
  sh "zip -qr '#{output}/#{app_name}.app.dSYM.zip' '#{output}/#{app_name}.app.dSYM/'"
end

