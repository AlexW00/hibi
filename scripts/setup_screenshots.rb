#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds the HibiUITests UI-test target and a dedicated "HibiScreenshots" shared
# scheme to Hibi.xcodeproj, compiling every Swift file in HibiUITests/.
#
# Idempotent + self-healing: each run removes any existing HibiUITests target
# and recreates it cleanly, so a previously broken target can't linger. Driven
# by scripts/screenshots.sh, but you can run it standalone:
#
#   ruby scripts/setup_screenshots.rb
#
# Requires the `xcodeproj` gem (bundled with fastlane; otherwise: gem install xcodeproj).

require "xcodeproj"

PROJECT_PATH   = File.expand_path("../Hibi.xcodeproj", __dir__)
APP_TARGET     = "Hibi"
UITEST_TARGET  = "HibiUITests"
UITEST_DIR     = "HibiUITests"
BUNDLE_ID      = "com.weichart.hibi.HibiUITests"
SCHEME_NAME    = "HibiScreenshots"
DEPLOYMENT     = "26.0"

project = Xcodeproj::Project.open(PROJECT_PATH)

app_target = project.targets.find { |t| t.name == APP_TARGET }
raise "Could not find the #{APP_TARGET} target" if app_target.nil?

# Remove any existing UI-test target and recreate it cleanly every run. This
# is self-healing: a target left half-configured by an older script version
# (notably with an empty PRODUCT_NAME, which builds as ".xctest"/"-Runner.app"
# and fails with "Multiple commands produce …/PlugIns/.xctest") gets rebuilt
# from scratch with the correct settings.
existing = project.targets.find { |t| t.name == UITEST_TARGET }
if existing
  puts "Removing existing #{UITEST_TARGET} target (clean recreate)…"
  existing.product_reference&.remove_from_project
  existing.remove_from_project
end

puts "Creating #{UITEST_TARGET} UI-test target…"
ui_target = project.new_target(:ui_test_bundle, UITEST_TARGET, :ios, DEPLOYMENT,
                               project.products_group, :swift)

ui_target.build_configurations.each do |config|
  # PRODUCT_NAME must be explicit — without it the bundle builds with an empty
  # name and the build fails with "Multiple commands produce …/PlugIns/.xctest".
  config.build_settings["PRODUCT_NAME"]                 = "$(TARGET_NAME)"
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"]    = BUNDLE_ID
  config.build_settings["TEST_TARGET_NAME"]             = APP_TARGET
  config.build_settings["GENERATE_INFOPLIST_FILE"]      = "YES"
  config.build_settings["SWIFT_VERSION"]                = "5.0"
  config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"]   = DEPLOYMENT
  config.build_settings["CODE_SIGN_STYLE"]              = "Automatic"
  config.build_settings["TARGETED_DEVICE_FAMILY"]       = "1,2"
  config.build_settings["SWIFT_EMIT_LOC_STRINGS"]       = "NO"
  # Inherit DEVELOPMENT_TEAM etc. from the same xcconfig the app uses, so a
  # physical-device run signs the same way. (Simulator runs don't need it.)
  app_cfg = app_target.build_configurations.find { |c| c.name == config.name }
  config.base_configuration_reference = app_cfg&.base_configuration_reference
end

ui_target.add_dependency(app_target)

# --- Sync HibiUITests/*.swift into the target's compile sources -------------

group = project.main_group.find_subpath(UITEST_DIR, true)
group.set_source_tree("SOURCE_ROOT")
group.set_path(UITEST_DIR)

Dir.glob(File.join(File.dirname(__dir__), UITEST_DIR, "*.swift")).sort.each do |file|
  basename = File.basename(file)
  ref = group.files.find { |f| f.display_name == basename } || group.new_reference(basename)
  ui_target.add_file_references([ref])
  puts "  + #{UITEST_DIR}/#{basename}"
end

# --- Shared scheme: HibiScreenshots (always rewritten for the fresh target) --

puts "Writing shared scheme #{SCHEME_NAME}…"
scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(app_target, ui_target)
# Demo mode is DEBUG-only — build/test/run Debug.
scheme.test_action.build_configuration = "Debug"
scheme.launch_action.build_configuration = "Debug"
scheme.save_as(PROJECT_PATH, SCHEME_NAME, true)

project.save
puts "Done. Target '#{UITEST_TARGET}' and scheme '#{SCHEME_NAME}' are ready."
