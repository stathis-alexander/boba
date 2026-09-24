# typed: strict
# frozen_string_literal: true

require "spec_helper"

require "active_record"
require "rails"
require "ruby_llm"
require "ruby_llm/active_record/chat_methods"
require "ruby_llm/active_record/message_methods"
require "ruby_llm/active_record/acts_as"

module Tapioca
  module Dsl
    module Compilers
      class RubyLLMSpec < ::DslSpec
        before do
          ::ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
          # Including `ActsAs` defaults both stores to the gem's own Active Record models. Loading those
          # would add them to the constants every other compiler's spec gathers, and nothing here reads them.
          ::RubyLLM.config.model_registry_store ||= ::Object
          ::RubyLLM.config.batch_store ||= ::Object
          ::ActiveRecord::Base.include(::RubyLLM::ActiveRecord::ActsAs)
        end

        after do
          ::ActiveRecord::Base.connection.disconnect!
        end

        describe "Tapioca::Dsl::Compilers::RubyLLM" do
          describe "initialize" do
            it "gathers no constants if there are no ActiveRecord classes" do
              assert_empty(gathered_constants)
            end

            it "gathers only models calling an acts_as method" do
              add_ruby_file("schema.rb", <<~RUBY)
                ActiveRecord::Migration.suppress_messages do
                  ActiveRecord::Schema.define do
                    create_table :chats do |t|
                      t.string :model_id
                    end

                    create_table :posts
                  end
                end
              RUBY

              add_ruby_file("models.rb", <<~RUBY)
                class Chat < ActiveRecord::Base
                  acts_as_chat
                end

                class Post < ActiveRecord::Base
                end
              RUBY

              assert_equal(["Chat"], gathered_constants)
            end
          end

          describe "decorate" do
            it "declares the mixins the acts_as call adds to the model" do
              add_ruby_file("schema.rb", <<~RUBY)
                ActiveRecord::Migration.suppress_messages do
                  ActiveRecord::Schema.define do
                    create_table :chats do |t|
                      t.string :model_id
                    end
                  end
                end
              RUBY

              add_ruby_file("chat.rb", <<~RUBY)
                class Chat < ActiveRecord::Base
                  acts_as_chat
                end
              RUBY

              rbi = rbi_for(:Chat)

              assert_includes(rbi, "include RubyLLM::ActiveRecord::ChatMethods\n")

              refute_includes(rbi, "include RubyLLM::ActiveRecord::ActsAs\n")
              refute_includes(rbi, "extend RubyLLM::ActiveRecord::ActsAs::ClassMethods\n")
            end

            it "re-declares the Enumerable type member for a chat" do
              add_ruby_file("schema.rb", <<~RUBY)
                ActiveRecord::Migration.suppress_messages do
                  ActiveRecord::Schema.define do
                    create_table :chats do |t|
                      t.string :model_id
                    end
                  end
                end
              RUBY

              add_ruby_file("chat.rb", <<~RUBY)
                class Chat < ActiveRecord::Base
                  acts_as_chat
                end
              RUBY

              rbi = rbi_for(:Chat)

              assert_includes(rbi, "Elem = type_member { { fixed: ::RubyLLM::Message } }\n")
            end
          end
        end
      end
    end
  end
end
