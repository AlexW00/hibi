#!/usr/bin/env ruby
# frozen_string_literal: true

# Idempotently adds the HibiUITests UI-test target and a dedicated
# "HibiScreenshots" shared scheme to Hibi.xcodeproj, then makes sure every
# Swift file in HibiUITests/ is compiled by the target.
#
# Safe to run repeatedly — it only creates what's missing. Driven by
# scripts/screenshots.sh, but you can run it standalone:
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

ui_target = project.targets.find { |t| t.name == UITEST_TARGET }

if ui_target.nil?
  puts "Creating #{UITEST_TARGET} UI-test target…"
  ui_target = project.new_target(:ui_test_bundle, UITEST_TARGET, :ios, DEPLOYMENT,
                                 project.products_group, :swift)

  ui_target.build_configurations.each do |config|
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
else
  puts "#{UITEST_TARGET} target already exists — syncing sources."
end

# --- Sync HibiUITests/*.swift into the target's compile sources -------------

group = project.main_group.find_subpath(UITEST_DIR, true)
group.set_source_tree("SOURCE_ROOT")
group.set_path(UITEST_DIR)

existing_paths = ui_target.source_build_phase.files_references.map { |r| r.real_path.to_s }

Dir.glob(File.join(File.dirname(__dir__), UITEST_DIR, "*.swift")).sort.each do |file|
  basename = File.basename(file)
  next if existing_paths.any? { |p| File.basename(p) == basename }

  ref = group.files.find { |f| f.display_name == basename } || group.new_reference(basename)
  ui_target.add_file_references([ref])
  puts "  + #{UITEST_DIR}/#{basename}"
end

# --- Shared scheme: HibiScreenshots ----------------------------------------

scheme_dir = File.join(PROJECT_PATH, "xcshareddata", "xcschemes")
scheme_file = File.join(scheme_dir, "#{SCHEME_NAME}.xcscheme")

unless File.exist?(scheme_file)
  puts "Creating shared scheme #{SCHEME_NAME}…"
  scheme = Xcodeproj::XCScheme.new
  scheme.configure_with_targets(app_target, ui_target)
  # Demo mode is DEBUG-only — build/test/run Debug.
  scheme.test_action.build_configuration = "Debug"
  scheme.launch_action.build_configuration = "Debug"
  scheme.save_as(PROJECT_PATH, SCHEME_NAME, true)
end

project.save
puts "Done. Target '#{UITEST_TARGET}' and scheme '#{SCHEME_NAME}' are ready."
