# typed: strict
# frozen_string_literal: true

return unless defined?(Ransack)

require "tapioca/dsl/helpers/active_record_constants_helper"

module Tapioca
  module Dsl
    module Compilers
      # `Tapioca::Dsl::Compilers::Ransack` decorates RBI files for models searchable with the `ransack` gem.
      # https://github.com/activerecord-hackery/ransack
      #
      # The class methods (`ransack`, `ransacker`, `ransackable_attributes`, ...) need no compiler: ransack
      # extends `ActiveRecord::Base` from an `ActiveSupport.on_load(:active_record)` hook, and anything that
      # loads `ActiveRecord::Base` during gem RBI generation fires it, so tapioca records the extend in the
      # gem RBI. What stays invisible is the relation side: `ActiveRecord::Relation` reaches those methods by
      # delegating to the model class, which Sorbet cannot follow.
      #
      # For example, with the following `ActiveRecord::Base` subclass:
      #
      # ~~~rb
      # class Post < ApplicationRecord
      # end
      # ~~~
      #
      # This compiler will produce the RBI file `post.rbi` with the following content:
      #
      # ~~~rbi
      # # post.rbi
      # # typed: true
      # class Post
      #   module GeneratedAssociationRelationMethods
      #     sig { params(params: T.untyped, options: T.untyped).returns(::Ransack::Search) }
      #     def ransack(params = nil, options = nil); end
      #
      #     sig { params(params: T.untyped, options: T.untyped).returns(::Ransack::Search) }
      #     def ransack!(params = nil, options = nil); end
      #   end
      #
      #   module GeneratedRelationMethods
      #     sig { params(params: T.untyped, options: T.untyped).returns(::Ransack::Search) }
      #     def ransack(params = nil, options = nil); end
      #
      #     sig { params(params: T.untyped, options: T.untyped).returns(::Ransack::Search) }
      #     def ransack!(params = nil, options = nil); end
      #   end
      # end
      # ~~~
      #
      # The signatures are the ones the gem RBI already carries for
      # `Ransack::Adapters::ActiveRecord::Base`; only the delegation is re-stated.
      class Ransack < Tapioca::Dsl::Compiler
        include Helpers::ActiveRecordConstantsHelper

        ConstantType = type_member { { fixed: T.class_of(::ActiveRecord::Base) } }

        # @override
        #: -> void
        def decorate
          root.create_path(constant) do |model|
            [RelationMethodsModuleName, AssociationRelationMethodsModuleName].each do |module_name|
              relation_methods_module = model.create_module(module_name)

              ["ransack", "ransack!"].each do |method_name|
                relation_methods_module.create_method(
                  method_name,
                  parameters: [
                    create_opt_param("params", type: "T.untyped", default: "nil"),
                    create_opt_param("options", type: "T.untyped", default: "nil"),
                  ],
                  return_type: "::Ransack::Search",
                )
              end
            end
          end
        end

        class << self
          # @override
          #: -> Enumerable[Module[top]]
          def gather_constants
            descendants_of(::ActiveRecord::Base).reject(&:abstract_class?)
          end
        end
      end
    end
  end
end
