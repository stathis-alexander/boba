# typed: true
# frozen_string_literal: true

# Add your extra requires here (`bin/tapioca require` can be used to bootstrap this list)

require "active_storage"
require "active_storage/reflection"
require "minitest/spec"
require "money-rails/active_record/monetizable"
require "paper_trail/frameworks/active_record"
require "paperclip/railtie"
require "rails/all"
require "ruby_llm/active_record/acts_as"
require "ruby_llm/active_record/chat_methods"
require "ruby_llm/active_record/message_methods"
require "rails/generators"
require "rails/generators/app_base"

tapioca_gem_folder = File.join(
  Gem::Specification.find_by_name("tapioca").gem_dir,
  "lib",
  "tapioca",
  "dsl",
  "**",
  "*.rb",
)
Dir[tapioca_gem_folder].each { |file| require file }

require "tapioca/helpers/test/dsl_compiler"
require "zeitwerk"
