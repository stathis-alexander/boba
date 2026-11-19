# Boba

> This project has moved from `angellist/boba` to [`stathis-alexander/boba`](https://github.com/stathis-alexander/boba).

> :warning: This software is currently under active development. It should not be considered stable until 1.0.0.

Boba is a collection of compilers for Sorbet & Tapioca.

Tapioca is very opinionated about what types of compilers or changes are accepted into the repository. See [here](https://github.com/Shopify/tapioca?tab=readme-ov-file#dsl-compilers). Boba come in all different shapes, sizes, consistencies, etc, and is much less opinionated about what is or is not accepted. Boba is a collection of optional compilers that you can pick and choose from.

### Available Compilers

See [the compilers manual](https://github.com/stathis-alexander/boba/blob/main/manual/compilers.md) for a list of available compilers.

## Usage

Add Boba to your development dependencies in your gemfile:
```ruby
group :development do
  gem 'boba', require: false
end
```

We recommend you also use the `only` configuration option in your Tapioca config (typically `sorbet/tapioca/config.yml`) to specify only the Tapioca compilers you wish to use. For instance, the following is an example `tapioca/config.yml` using the Boba `ActiveRecord` compilers:

```yml
gem:
dsl:
  only:
    - ActiveRecordAssociationsPersisted
    - ActiveRecordColumnsPersisted
```

This makes it easy to selectively enable only the compilers you want to use in your project.

### Typing Relations

If you'd like to use relation types in your sigs that are less broad than `ActiveRecord::Relation`, such as those specific to a model, Boba provides a railtie to initialize these constants for each class. Move Boba in your gemfile out of the development group:

```ruby
  gem 'boba'
```

The railtie will automatically define the `PrivateRelation`, `PrivateAssociationRelation`, and `PrivateCollectionProxy` constants on each model that inherits from `ActiveRecord::Base`. These are defined as their corresponding private `ActiveRecord` classes, so runtime type checking works as expected. They can then be used in typing, like so:

```ruby
class Post < ::ActiveRecord::Base
  scope :recent -> { where('created_at > ?', Date.current) }

  belongs_to :author
  has_many :comments
end

sig { params(author: Author).returns(Post::PrivateRelation) }
def posts_from_author(author); end
```

and the following should not raise a Sorbet error:

```ruby
sig { params(author: Author).returns(Post::PrivateRelation) }
def recent_posts_from_author(author)
  posts_from_author(author).recent
end
```

Boba also defines a type alias `RelationType` on each such class, which is defined as the union of the three relation types. This is useful because the relation types are often used interchangeably and so you may expect to return or pass any of the three classes as an argument. To use this, you will also need to use the `ActiveRecordRelationTypes` compiler to generate the type alias in the signatures as well (or define them manually in shims).

```ruby
sig { params(author: Author).returns(Post::RelationType) }
def recent_posts_from_author(author)
  posts_from_author(author).recent
end
```

### A Note on Tapioca Dependencies

The core `ActiveRecordAssociationsPersisted` and `ActiveRecordColumnsPersisted` compilers are extensions of Tapioca's corresponding compilers, and depend on monkey patching internal methods. As such, Boba's dependent Tapioca version must be restricted to known good versions and cannot use the more lenient pessimistic version pinning (`~>`), since even minor or patch versions of Tapioca can introduce breaking changes that would be frustrating or difficult for consumers.

We try to stay as up-to-date with Tapioca versions as possible, but can sometimes fall behind. Please submit an issue or pull request (including any needed updates) if we miss a Tapioca version you'd like to upgrade to, and we will address it as soon as possible.

## Contributing

Bugs and feature requests are welcome and should be [filed as issues on github](https://github.com/stathis-alexander/boba/issues).

### New Compilers

Compilers for any commonly used Ruby or Rails gems are welcome to be contributed. See the [Writing New Compilers section of the Tapioca docs](https://github.com/Shopify/tapioca?tab=readme-ov-file#writing-custom-dsl-compilers) for an introduction to writing compilers.

Since Boba is intended to be used alongside Tapioca and the compilers provided by Boba are intended to be fully optional, we will not accept compilers which overwrite the Tapioca default compilers. See the [Tapioca Manual](https://github.com/Shopify/tapioca/blob/main/manual/compilers.md) for a list of these compilers. Instead, compilers which extend or overwrite the default Tapioca compilers should be given unique names.

Contributed compilers should be well documented, and named after and include a link or reference to the Gem, DSL, or other module they implement RBIs for.

Compilers for Gems, DSLs, or modules that are not publicly available will not be accepted.

### Releasing

1. Bump the version in `lib/boba/version.rb`, and commit.
2. Add a new tag: `git tag vX.Y.Z`.
3. Then push `git push origin head vX.Y.Z`.
