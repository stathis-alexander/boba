# typed: strict
# frozen_string_literal: true

return unless defined?(RubyLLM::ActiveRecord)

module Tapioca
  module Dsl
    module Compilers
      # `Tapioca::Dsl::Compilers::RubyLLM` decorates RBI files for models using the `acts_as_*` DSL of the
      # `ruby_llm` gem. https://github.com/crmne/ruby_llm
      #
      # The `acts_as_*` class methods themselves are out of reach of a compiler and of gem RBI generation
      # alike: the gem includes `RubyLLM::ActiveRecord::ActsAs` into `ActiveRecord::Base` from an
      # `on_load(:active_record)` hook inside a **railtie initializer**, so nothing short of booting the
      # application runs it. Declare that one include in a shim, and the DSL types itself from the gem RBI:
      #
      # ~~~rbi
      # # sorbet/rbi/shims/ruby_llm.rbi
      # class ActiveRecord::Base
      #   include RubyLLM::ActiveRecord::ActsAs
      # end
      # ~~~
      #
      # What is left for a compiler is per model: the methods module each `acts_as_*` call mixes into the
      # class that declares it.
      #
      # For example, with the following `ActiveRecord::Base` subclass:
      #
      # ~~~rb
      # class Chat < ApplicationRecord
      #   acts_as_chat
      # end
      # ~~~
      #
      # This compiler will produce the RBI file `chat.rbi` with the following content:
      #
      # ~~~rbi
      # # chat.rbi
      # # typed: true
      # class Chat
      #   include RubyLLM::ActiveRecord::ChatMethods
      #
      #   Elem = type_member { { fixed: ::RubyLLM::Message } }
      # end
      # ~~~
      #
      # The module is declared rather than re-implemented, so `ask`, `with_instructions`,
      # `with_runtime_instructions` and the rest keep the signatures they have in the gem RBI. Models that
      # never call an `acts_as_*` method are left alone.
      #
      # Since ruby_llm 2.0 `ChatMethods` includes `Enumerable` and hands `each` over to the underlying
      # `RubyLLM::Chat`, which yields `RubyLLM::Message`s. A class that includes a generic module has to
      # re-declare its type members, so the chat model gets `Elem` fixed to that; on older versions,
      # where the module is not enumerable, nothing is added.
      class RubyLLM < Tapioca::Dsl::Compiler
        ConstantType = type_member { { fixed: T.class_of(::ActiveRecord::Base) } }

        # One module per `acts_as_*`, under both the current and the legacy API; the names are fixed, so
        # there is nothing to discover by walking ancestors with a name prefix.
        MIXINS = [
          "RubyLLM::ActiveRecord::ChatMethods",
          "RubyLLM::ActiveRecord::MessageMethods",
          "RubyLLM::ActiveRecord::ModelMethods",
          "RubyLLM::ActiveRecord::ToolCallMethods",
          "RubyLLM::ActiveRecord::ChatLegacyMethods",
          "RubyLLM::ActiveRecord::MessageLegacyMethods",
        ] #: Array[String]

        # What `each` yields for the mixins that are `Enumerable`.
        ELEMS = {
          "RubyLLM::ActiveRecord::ChatMethods" => "::RubyLLM::Message",
        } #: Hash[String, String]

        # @override
        #: -> void
        def decorate
          mixins = self.class.mixins_of(constant)

          root.create_path(constant) do |model|
            mixins.each { |name| model.create_include(name) }

            elem = enumerable_elem(mixins)
            model.create_type_variable("Elem", type: "type_member", fixed: elem) if elem
          end
        end

        private

        #: (Array[String] mixins) -> String?
        def enumerable_elem(mixins)
          return unless constant < ::Enumerable

          mixins.filter_map { |name| ELEMS[name] }.first
        end

        class << self
          # @override
          #: -> Enumerable[Module[top]]
          def gather_constants
            descendants_of(::ActiveRecord::Base)
              .reject(&:abstract_class?)
              .select { |model| mixins_of(model).any? }
          end

          # The DSL itself is included into `ActiveRecord::Base`, so every model carries it. What tells a
          # model apart is the methods module an `acts_as_*` call mixed into the model itself.
          #: (singleton(::ActiveRecord::Base) model) -> Array[String]
          def mixins_of(model)
            own_ancestors = model.ancestors - ::ActiveRecord::Base.ancestors
            names = own_ancestors.filter_map(&:name)

            MIXINS & names
          end
        end
      end
    end
  end
end
