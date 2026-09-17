# typed: strict
# frozen_string_literal: true

require "spec_helper"

require "active_record"
require "rails"
require "ransack"

module Tapioca
  module Dsl
    module Compilers
      class RansackSpec < ::DslSpec
        before do
          ::ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
        end

        after do
          ::ActiveRecord::Base.connection.disconnect!
        end

        describe "Tapioca::Dsl::Compilers::Ransack" do
          describe "initialize" do
            it "gathers no constants if there are no ActiveRecord classes" do
              assert_empty(gathered_constants)
            end

            it "gathers only non-abstract ActiveRecord classes" do
              add_ruby_file("post.rb", <<~RUBY)
                class Post < ActiveRecord::Base
                end

                class AbstractPost < ActiveRecord::Base
                  self.abstract_class = true
                end
              RUBY

              assert_equal(["Post"], gathered_constants)
            end
          end

          describe "decorate" do
            it "generates the relation methods ransack reaches by delegation" do
              add_ruby_file("schema.rb", <<~RUBY)
                ActiveRecord::Migration.suppress_messages do
                  ActiveRecord::Schema.define do
                    create_table :posts do |t|
                      t.string :title
                    end
                  end
                end
              RUBY

              add_ruby_file("post.rb", <<~RUBY)
                class Post < ActiveRecord::Base
                end
              RUBY

              expected = template(<<~RBI, trim_mode: "-")
                # typed: strong

                class Post
                  module GeneratedAssociationRelationMethods
                    sig { params(params: T.untyped, options: T.untyped).returns(::Ransack::Search) }
                    def ransack(params = nil, options = nil); end

                    sig { params(params: T.untyped, options: T.untyped).returns(::Ransack::Search) }
                    def ransack!(params = nil, options = nil); end
                  end

                  module GeneratedRelationMethods
                    sig { params(params: T.untyped, options: T.untyped).returns(::Ransack::Search) }
                    def ransack(params = nil, options = nil); end

                    sig { params(params: T.untyped, options: T.untyped).returns(::Ransack::Search) }
                    def ransack!(params = nil, options = nil); end
                  end
                end
              RBI

              assert_equal(rbi_for(:Post), expected)
            end
          end
        end
      end
    end
  end
end
