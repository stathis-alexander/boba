# typed: strict
# frozen_string_literal: true

require "tapioca/dsl/compilers/active_record_columns"

return unless defined?(Tapioca::Dsl::Compilers::ActiveRecordColumns)

require "boba/active_record/attribute_service"
require "tapioca/dsl/helpers/active_record_column_type_helper"

module Tapioca
  module Dsl
    module Compilers
      # `Tapioca::Dsl::Compilers::ActiveRecordColumnsPersisted` is an extension of the default Tapioca compiler `Tapioca::Dsl::Compilers::ActiveRecordColumns`.
      #
      # [`ActiveRecord::Base`](https://api.rubyonrails.org/classes/ActiveRecord/Base.html).
      # This compiler is only responsible for defining the attribute methods that would be
      # created for columns and virtual attributes that are defined in the Active Record
      # model.
      #
      # For example, with the following model class:
      # ~~~rb
      # class Post < ActiveRecord::Base
      # end
      # ~~~
      #
      # and the following database schema:
      #
      # ~~~rb
      # # db/schema.rb
      # create_table :posts do |t|
      #   t.string :title, null: false
      #   t.string :body
      #   t.boolean :published
      #   t.timestamps
      # end
      # ~~~
      #
      # this compiler will produce the following methods in the RBI file
      # `post.rbi`:
      #
      # ~~~rbi
      # # post.rbi
      # # typed: true
      # class Post
      #   include GeneratedAttributeMethods
      #
      #   module GeneratedAttributeMethods
      #     sig { returns(T.nilable(::String)) }
      #     def body; end
      #
      #     sig { params(value: T.nilable(::String)).returns(T.nilable(::String)) }
      #     def body=; end
      #
      #     sig { returns(T::Boolean) }
      #     def body?; end
      #
      #     sig { returns(T.nilable(::ActiveSupport::TimeWithZone)) }
      #     def created_at; end
      #
      #     sig { params(value: ::ActiveSupport::TimeWithZone).returns(::ActiveSupport::TimeWithZone) }
      #     def created_at=; end
      #
      #     sig { returns(T::Boolean) }
      #     def created_at?; end
      #
      #     sig { returns(T.nilable(T::Boolean)) }
      #     def published; end
      #
      #     sig { params(value: T::Boolean).returns(T::Boolean) }
      #     def published=; end
      #
      #     sig { returns(T::Boolean) }
      #     def published?; end
      #
      #     sig { returns(::String) }
      #     def title; end
      #
      #     sig { params(value: ::String).returns(::String) }
      #     def title=(value); end
      #
      #     sig { returns(T::Boolean) }
      #     def title?; end
      #
      #     sig { returns(T.nilable(::ActiveSupport::TimeWithZone)) }
      #     def updated_at; end
      #
      #     sig { params(value: ::ActiveSupport::TimeWithZone).returns(::ActiveSupport::TimeWithZone) }
      #     def updated_at=; end
      #
      #     sig { returns(T::Boolean) }
      #     def updated_at?; end
      #
      #     ## Also the methods added by https://api.rubyonrails.org/classes/ActiveRecord/AttributeMethods/Dirty.html
      #     ## Also the methods added by https://api.rubyonrails.org/classes/ActiveModel/Dirty.html
      #     ## Also the methods added by https://api.rubyonrails.org/classes/ActiveRecord/AttributeMethods/BeforeTypeCast.html
      #   end
      # end
      # ~~~
      #
      class ActiveRecordColumnsPersisted < ::Tapioca::Dsl::Compilers::ActiveRecordColumns
        ConstantType = type_member { { fixed: T.class_of(ActiveRecord::Base) } }

        private

        #: -> ::Tapioca::Dsl::Helpers::ActiveRecordColumnTypeHelper
        def column_type_helper
          ::Tapioca::Dsl::Helpers::ActiveRecordColumnTypeHelper.new(
            constant,
            column_type_option: Helpers::ActiveRecordColumnTypeHelper::ColumnTypeOption::Persisted,
          )
        end

        #: (String attribute_name, ?String column_name) -> [String, String]
        def type_for(attribute_name, column_name = attribute_name)
          column_type_helper = column_type_helper()
          return column_type_helper.send(:id_type) if attribute_name == "id"

          column_type_for(column_name, column_type_helper: column_type_helper)
        end

        #: (String column_name, column_type_helper: ::Tapioca::Dsl::Helpers::ActiveRecordColumnTypeHelper) -> [String, String]
        def column_type_for(column_name, column_type_helper:)
          nilable_column = Boba::ActiveRecord::AttributeService.nilable_attribute?(constant, column_name)

          column_type = constant.attribute_types[column_name]
          getter_type = column_type_helper.send(
            :type_for_activerecord_value,
            column_type,
            column_nullability: nilable_column,
          )
          setter_type = case column_type
          when ActiveRecord::Enum::EnumType
            column_type_helper.send(:enum_setter_type, column_type)
          else
            getter_type
          end

          virtual_attribute = Boba::ActiveRecord::AttributeService.virtual_attribute?(constant, column_name)
          if virtual_attribute || !nilable_column
            [getter_type, setter_type]
          else
            getter_type = as_nilable_type(getter_type) unless column_type_helper.send(
              :not_nilable_serialized_column?,
              column_type,
            )
            [getter_type, as_nilable_type(setter_type)]
          end
        end

        #: (RBI::Scope klass, String attribute_name, ?String column_name, ?Array[String]? methods_to_add) -> void
        def add_methods_for_attribute(klass, attribute_name, column_name = attribute_name, methods_to_add = nil)
          getter_type, setter_type = type_for(attribute_name, column_name)

          # Added by ActiveRecord::AttributeMethods::Read
          #
          add_method(
            klass,
            attribute_name.to_s,
            methods_to_add,
            return_type: getter_type,
          )

          # Added by ActiveRecord::AttributeMethods::Write
          #
          add_method(
            klass,
            "#{attribute_name}=",
            methods_to_add,
            parameters: [create_param("value", type: setter_type)],
            return_type: setter_type,
          )

          # Added by ActiveRecord::AttributeMethods::Query
          #
          add_method(
            klass,
            "#{attribute_name}?",
            methods_to_add,
            return_type: "T::Boolean",
          )

          # Added by ActiveRecord::AttributeMethods::Dirty
          #
          add_method(
            klass,
            "#{attribute_name}_before_last_save",
            methods_to_add,
            return_type: as_nilable_type(getter_type),
          )
          add_method(
            klass,
            "#{attribute_name}_change_to_be_saved",
            methods_to_add,
            return_type: "T.nilable([#{getter_type}, #{getter_type}])",
          )
          add_method(
            klass,
            "#{attribute_name}_in_database",
            methods_to_add,
            return_type: as_nilable_type(getter_type),
          )
          add_method(
            klass,
            "saved_change_to_#{attribute_name}",
            methods_to_add,
            return_type: "T.nilable([#{getter_type}, #{getter_type}])",
          )
          add_method(
            klass,
            "saved_change_to_#{attribute_name}?",
            methods_to_add,
            return_type: "T::Boolean",
            parameters: [
              create_kw_opt_param("from", type: "T.untyped", default: "T.unsafe(nil)"),
              create_kw_opt_param("to", type: "T.untyped", default: "T.unsafe(nil)"),
            ],
          )
          add_method(
            klass,
            "will_save_change_to_#{attribute_name}?",
            methods_to_add,
            return_type: "T::Boolean",
            parameters: [
              create_kw_opt_param("from", type: "T.untyped", default: "T.unsafe(nil)"),
              create_kw_opt_param("to", type: "T.untyped", default: "T.unsafe(nil)"),
            ],
          )

          # Added by ActiveModel::Dirty
          #
          add_method(
            klass,
            "#{attribute_name}_change",
            methods_to_add,
            return_type: "T.nilable([#{getter_type}, #{getter_type}])",
          )
          add_method(
            klass,
            "#{attribute_name}_changed?",
            methods_to_add,
            return_type: "T::Boolean",
            parameters: [
              create_kw_opt_param("from", type: "T.untyped", default: "T.unsafe(nil)"),
              create_kw_opt_param("to", type: "T.untyped", default: "T.unsafe(nil)"),
            ],
          )
          add_method(
            klass,
            "#{attribute_name}_will_change!",
            methods_to_add,
          )
          add_method(
            klass,
            "#{attribute_name}_was",
            methods_to_add,
            return_type: as_nilable_type(getter_type),
          )
          add_method(
            klass,
            "#{attribute_name}_previous_change",
            methods_to_add,
            return_type: "T.nilable([#{getter_type}, #{getter_type}])",
          )
          add_method(
            klass,
            "#{attribute_name}_previously_changed?",
            methods_to_add,
            return_type: "T::Boolean",
            parameters: [
              create_kw_opt_param("from", type: "T.untyped", default: "T.unsafe(nil)"),
              create_kw_opt_param("to", type: "T.untyped", default: "T.unsafe(nil)"),
            ],
          )
          add_method(
            klass,
            "#{attribute_name}_previously_was",
            methods_to_add,
            return_type: as_nilable_type(getter_type),
          )
          add_method(
            klass,
            "restore_#{attribute_name}!",
            methods_to_add,
          )

          # Added by ActiveRecord::AttributeMethods::BeforeTypeCast
          #
          add_method(
            klass,
            "#{attribute_name}_before_type_cast",
            methods_to_add,
            return_type: "T.untyped",
          )
          add_method(
            klass,
            "#{attribute_name}_came_from_user?",
            methods_to_add,
            return_type: "T::Boolean",
          )
        end
      end
    end
  end
end
