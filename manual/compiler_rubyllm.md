## RubyLLM

`Tapioca::Dsl::Compilers::RubyLLM` decorates RBI files for models using the `acts_as_*` DSL of the
`ruby_llm` gem. https://github.com/crmne/ruby_llm

The `acts_as_*` class methods themselves are out of reach of a compiler and of gem RBI generation
alike: the gem includes `RubyLLM::ActiveRecord::ActsAs` into `ActiveRecord::Base` from an
`on_load(:active_record)` hook inside a **railtie initializer**, so nothing short of booting the
application runs it. Declare that one include in a shim, and the DSL types itself from the gem RBI:

~~~rbi
# sorbet/rbi/shims/ruby_llm.rbi
class ActiveRecord::Base
  include RubyLLM::ActiveRecord::ActsAs
end
~~~

What is left for a compiler is per model: the methods module each `acts_as_*` call mixes into the
class that declares it.

For example, with the following `ActiveRecord::Base` subclass:

~~~rb
class Chat < ApplicationRecord
  acts_as_chat
end
~~~

This compiler will produce the RBI file `chat.rbi` with the following content:

~~~rbi
# chat.rbi
# typed: true
class Chat
  include RubyLLM::ActiveRecord::ChatMethods

  Elem = type_member { { fixed: ::RubyLLM::Message } }
end
~~~

The module is declared rather than re-implemented, so `ask`, `with_instructions`,
`with_runtime_instructions` and the rest keep the signatures they have in the gem RBI. Models that
never call an `acts_as_*` method are left alone.

Since ruby_llm 2.0 `ChatMethods` includes `Enumerable` and hands `each` over to the underlying
`RubyLLM::Chat`, which yields `RubyLLM::Message`s. A class that includes a generic module has to
re-declare its type members, so the chat model gets `Elem` fixed to that; on older versions,
where the module is not enumerable, nothing is added.
