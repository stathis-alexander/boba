# typed: strict
# frozen_string_literal: true

require "spec_helper"

require "active_record"
require "rails"
require "acts-as-taggable-on"

module Tapioca
  module Dsl
    module Compilers
      class ActsAsTaggableOnSpec < ::DslSpec
        before do
          ::ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
        end

        after do
          ::ActiveRecord::Base.connection.disconnect!
        end

        describe "Tapioca::Dsl::Compilers::ActsAsTaggableOn" do
          describe "initialize" do
            it "gathers no constants if there are no ActiveRecord classes" do
              assert_empty(gathered_constants)
            end

            it "gathers only taggable models" do
              add_ruby_file("schema.rb", <<~RUBY)
                ActiveRecord::Migration.suppress_messages do
                  ActiveRecord::Schema.define do
                    create_table :posts
                    create_table :comments
                  end
                end
              RUBY

              add_ruby_file("models.rb", <<~RUBY)
                class Post < ActiveRecord::Base
                  acts_as_taggable_on :tags
                end

                class Comment < ActiveRecord::Base
                end
              RUBY

              assert_equal(["Post"], gathered_constants)
            end
          end

          describe "decorate" do
            it "generates methods for every tag context" do
              add_ruby_file("schema.rb", <<~RUBY)
                ActiveRecord::Migration.suppress_messages do
                  ActiveRecord::Schema.define do
                    create_table :posts
                  end
                end
              RUBY

              add_ruby_file("post.rb", <<~RUBY)
                class Post < ActiveRecord::Base
                  acts_as_taggable_on :skills
                end
              RUBY

              rbi = rbi_for(:Post)

              ["Core", "Collection", "Caching", "Ownership", "Related"].each do |mixin|
                assert_includes(rbi, "include ActsAsTaggableOn::Taggable::#{mixin}\n")
                assert_includes(rbi, "extend ActsAsTaggableOn::Taggable::#{mixin}::ClassMethods\n")
              end

              refute_includes(rbi, "extend ActsAsTaggableOn::Taggable\n")
              assert_includes(rbi, "def skill_list; end")
              assert_includes(rbi, "def skill_list=(new_tags); end")
              assert_includes(rbi, "def all_skills_list; end")
              assert_includes(rbi, "def skills_from(owner); end")
              assert_includes(rbi, "def find_related_skills(options = {}); end")
              assert_includes(rbi, "def find_related_on_skills(options = {}); end")
              assert_includes(rbi, "def find_related_skills_for(klass, options = {}); end")
              assert_includes(rbi, "def skill_counts(options = {}); end")
              assert_includes(rbi, "class << self")
              assert_equal(2, rbi.scan("def top_skills(limit = 10); end").size)
            end

            it "re-states the relation finders, untyped without the relations compiler" do
              add_ruby_file("schema.rb", <<~RUBY)
                ActiveRecord::Migration.suppress_messages do
                  ActiveRecord::Schema.define do
                    create_table :posts
                  end
                end
              RUBY

              add_ruby_file("post.rb", <<~RUBY)
                class Post < ActiveRecord::Base
                  acts_as_taggable_on :tags
                end
              RUBY

              rbi = rbi_for(:Post)

              assert_includes(rbi, "module GeneratedRelationMethods\n")
              assert_includes(rbi, "module GeneratedAssociationRelationMethods\n")
              assert_includes(rbi, "sig { params(tags: T.untyped, options: T.untyped).returns(T.untyped) }")
              assert_includes(rbi, "sig { params(context: T.untyped, options: T.untyped).returns(T.untyped) }")
            end

            it "types the relation finders when the relations compiler is enabled" do
              require "tapioca/dsl/compilers/active_record_relations"
              activate_other_dsl_compilers(ActiveRecordRelations)

              add_ruby_file("schema.rb", <<~RUBY)
                ActiveRecord::Migration.suppress_messages do
                  ActiveRecord::Schema.define do
                    create_table :posts
                  end
                end
              RUBY

              add_ruby_file("post.rb", <<~RUBY)
                class Post < ActiveRecord::Base
                  acts_as_taggable_on :tags
                end
              RUBY

              rbi = rbi_for(:Post)

              assert_includes(rbi, "sig { params(tags: T.untyped, options: T.untyped).returns(PrivateRelation) }")
              assert_includes(
                rbi,
                "sig { params(tags: T.untyped, options: T.untyped).returns(PrivateAssociationRelation) }",
              )
              assert_equal(
                2,
                rbi.scan(
                  "sig { params(context: T.untyped, options: T.untyped).returns(::ActsAsTaggableOn::Tag::PrivateRelation) }",
                ).size,
              )
            end
          end
        end
      end
    end
  end
end
