# typed: strict
# frozen_string_literal: true

require "tapioca/dsl/compilers/active_record_associations"

return unless defined?(Tapioca::Dsl::Compilers::ActiveRecordAssociations)

require "boba/active_record/reflection_service"
require "boba/options/association_type_option"

module Tapioca
  module Dsl
    module Compilers
      # `Tapioca::Dsl::Compilers::ActiveRecordAssociationsPersisted` extends the default Tapioca compiler `Tapioca::Dsl::Compilers::ActiveRecordAssociations`
      # to provide an option to generate RBI files for associations on models assuming that the model is persisted. These sigs therefore respect
      # validations and DB constraints, and generate non-nilable types for associations that are required or non-optional.
      #
      # This compiler accepts a `ActiveRecordAssociationTypes` option that can be used to specify
      # how the types of `belongs_to` and `has_one` associations should be generated. The option can be one of the
      # following:
      #  - `nilable (_default_)`: All association methods will be generated with `T.nilable` return types. This is
      #  strictly the most correct way to type the methods, but it can make working with the models more cumbersome, as
      #  you will have to handle the `nil` cases explicitly using `T.must` or the safe navigation operator `&.`, even
      #  for valid persisted models.
      #  - `persisted`: The methods will be generated with the type that matches validations on the association. If
      #  there is a `required: true` or `optional: false`, then the types will be generated as non-nilable. This mode
      #  basically treats each model as if it was a valid and persisted model. Note that this makes typing Active Record
      #  models easier, but does not match the behaviour of non-persisted or invalid models, which can have `nil`
      #  associations.
      #
      # For example, with the following model class:
      #
      # ~~~rb
      # class Post < ActiveRecord::Base
      #   belongs_to :category
      #   has_many :comments
      #   has_one :author, class_name: "User", optional: false
      #
      #   accepts_nested_attributes_for :category, :comments, :author
      # end
      # ~~~
      #
      # By default, the compiler will generate types consistent with `Tapioca::Dsl::Compilers::ActiveRecordAssociationsPersisted`.
      # If `ActiveRecordAssociationTypes` is `persisted`, the `author` method will be generated as:
      # ~~~rbi
      #     sig { returns(::User) }
      #     def author; end
      # ~~~
      # and if the option is set to `untyped`, the `author` method will be generated as:
      # ~~~rbi
      #     sig { returns(T.untyped) }
      #     def author; end
      # ~~~
      class ActiveRecordAssociationsPersisted < ::Tapioca::Dsl::Compilers::ActiveRecordAssociations
        ConstantType = type_member { { fixed: T.class_of(ActiveRecord::Base) } }

        private

        #: (RBI::Scope klass, (String | Symbol) association_name, ReflectionType reflection) -> void
        def populate_single_assoc_getter_setter(klass, association_name, reflection)
          association_class = type_for(reflection)
          association_type = single_association_type_for(reflection)
          association_methods_module = constant.generated_association_methods

          klass.create_method(
            association_name.to_s,
            return_type: association_type,
          )
          klass.create_method(
            "#{association_name}=",
            parameters: [create_param("value", type: association_type)],
            return_type: "void",
          )
          klass.create_method(
            "reload_#{association_name}",
            return_type: association_type,
          )
          klass.create_method(
            "reset_#{association_name}",
            return_type: "void",
          )
          if association_methods_module.method_defined?("#{association_name}_changed?")
            klass.create_method(
              "#{association_name}_changed?",
              return_type: "T::Boolean",
            )
          end
          if association_methods_module.method_defined?("#{association_name}_previously_changed?")
            klass.create_method(
              "#{association_name}_previously_changed?",
              return_type: "T::Boolean",
            )
          end
          unless reflection.polymorphic?
            klass.create_method(
              "build_#{association_name}",
              parameters: [
                create_rest_param("args", type: "T.untyped"),
                create_block_param("blk", type: "T.untyped"),
              ],
              return_type: association_class,
            )
            klass.create_method(
              "create_#{association_name}",
              parameters: [
                create_rest_param("args", type: "T.untyped"),
                create_block_param("blk", type: "T.untyped"),
              ],
              return_type: association_class,
            )
            klass.create_method(
              "create_#{association_name}!",
              parameters: [
                create_rest_param("args", type: "T.untyped"),
                create_block_param("blk", type: "T.untyped"),
              ],
              return_type: association_class,
            )
          end
        end

        #: (ReflectionType reflection) -> String
        def single_association_type_for(reflection)
          association_class = type_for(reflection)

          if Boba::ActiveRecord::ReflectionService.required_reflection?(reflection)
            association_class
          else
            as_nilable_type(association_class)
          end
        end
      end
    end
  end
end
