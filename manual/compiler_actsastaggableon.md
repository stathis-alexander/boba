## ActsAsTaggableOn

`Tapioca::Dsl::Compilers::ActsAsTaggableOn` decorates RBI files for models using the
`acts-as-taggable-on` gem. https://github.com/mbleigh/acts-as-taggable-on

`acts_as_taggable_on` itself needs no compiler: the gem extends `ActiveRecord::Base` from an
`ActiveSupport.on_load(:active_record)` hook, and anything that loads `ActiveRecord::Base` during gem
RBI generation fires it, so tapioca records the extend in the gem RBI. What only exists per model is
what the declaration then installs on the declaring class: the five mixin pairs that carry the
tagging API, and one set of accessors per tag context.

For example, with the following `ActiveRecord::Base` subclass:

~~~rb
class Post < ApplicationRecord
  acts_as_taggable_on :tags
end
~~~

This compiler will produce the RBI file `post.rbi` with the following content:

~~~rbi
# post.rbi
# typed: true
class Post
  include ActsAsTaggableOn::Taggable::Core
  extend ActsAsTaggableOn::Taggable::Core::ClassMethods
  include ActsAsTaggableOn::Taggable::Collection
  extend ActsAsTaggableOn::Taggable::Collection::ClassMethods

  sig { returns(::ActsAsTaggableOn::TagList) }
  def all_tags_list; end

  sig { params(options: T.untyped).returns(T.untyped) }
  def find_related_on_tags(options = {}); end

  sig { params(options: T.untyped).returns(T.untyped) }
  def find_related_tags(options = {}); end

  sig { params(klass: T.untyped, options: T.untyped).returns(T.untyped) }
  def find_related_tags_for(klass, options = {}); end

  sig { params(options: T.untyped).returns(T.untyped) }
  def tag_counts(options = {}); end

  sig { returns(::ActsAsTaggableOn::TagList) }
  def tag_list; end

  sig { params(new_tags: T.untyped).returns(T.untyped) }
  def tag_list=(new_tags); end

  sig { params(owner: T.untyped).returns(::ActsAsTaggableOn::TagList) }
  def tags_from(owner); end

  sig { params(limit: Integer).returns(T.untyped) }
  def top_tags(limit = 10); end

  class << self
    sig { params(options: T.untyped).returns(T.untyped) }
    def tag_counts(options = {}); end

    sig { params(limit: Integer).returns(T.untyped) }
    def top_tags(limit = 10); end
  end

  module GeneratedAssociationRelationMethods
    sig { params(context: T.untyped, options: T.untyped).returns(::ActsAsTaggableOn::Tag::PrivateRelation) }
    def tag_counts_on(context, options = {}); end

    sig { params(tags: T.untyped, options: T.untyped).returns(PrivateAssociationRelation) }
    def tagged_with(tags, options = {}); end
  end

  module GeneratedRelationMethods
    sig { params(context: T.untyped, options: T.untyped).returns(::ActsAsTaggableOn::Tag::PrivateRelation) }
    def tag_counts_on(context, options = {}); end

    sig { params(tags: T.untyped, options: T.untyped).returns(PrivateRelation) }
    def tagged_with(tags, options = {}); end
  end
end
~~~

The mixins are declared rather than re-implemented, so `tagged_with`, `tag_list_on` and the rest keep
the signatures they have in the gem RBI. Only the per-context methods, which exist for the contexts of
this model alone, are generated.

The relation side is the exception. `ActiveRecord::Relation` reaches the class methods by delegating to
the model class, which Sorbet cannot follow, so `Post.published.tagged_with(...)` does not type-check at
all. The two finders that answer a relation are re-stated on the relation modules: `tagged_with`
narrows the receiver, and `tag_counts_on` answers a relation of `ActsAsTaggableOn::Tag` rather than
of the model. Without the relations compiler both stay untyped.
