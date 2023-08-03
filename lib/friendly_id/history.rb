module FriendlyId
  module History
    def self.setup(model_class)
      model_class.instance_eval do
        friendly_id_config.use :slugged
        friendly_id_config.finder_methods = FriendlyId::History::FinderMethods
        if friendly_id_config.uses? :finders
          relation.class.send(:include, friendly_id_config.finder_methods)
          if ActiveRecord::VERSION::MAJOR == 4 && ActiveRecord::VERSION::MINOR == 2
            model_class.send(:extend, friendly_id_config.finder_methods)
          end
        end
      end
    end

    # Configures the model instance to use the History add-on.
    def self.included(model_class)
      model_class.class_eval do
        has_many :slugs, -> {order(Slug.arel_table[:id].desc)},
          as:         :sluggable,
          dependent:  :destroy,
          class_name: Slug.to_s

        after_save :create_slug
      end
    end

    module FinderMethods
      include ::FriendlyId::FinderMethods

      def exists_by_friendly_id?(id)
        joins(:slugs, :translations).where(translation_class.arel_table[friendly_id_config.query_field].eq(id)).exists? || joins(:slugs).where(slug_history_clause(id)).exists?
      end

      private

      def first_by_friendly_id(id)
        matching_record = where(friendly_id_config.query_field => id).first
        matching_record || slug_table_record(id)
      end

      def slug_table_record(id)
        select(quoted_table_name + '.*').joins(:slugs).where(slug_history_clause(id)).order(Slug.arel_table[:id].desc).first
      end

      def slug_history_clause(id)
        Slug.arel_table[:sluggable_type].eq(base_class.to_s).and(Slug.arel_table[:slug].eq(id)).and(Slug.arel_table[:locale].eq(::Mobility.locale))
      end
    end

    private

    # If we're updating, don't consider historic slugs for the same record
    # to be conflicts. This will allow a record to revert to a previously
    # used slug.
    def scope_for_slug_generator
      relation = super
      return relation if new_record?
      relation = relation.merge(Slug.where('sluggable_id <> ?', id))
      if friendly_id_config.uses?(:scoped)
        relation = relation.where(Slug.arel_table[:scope].eq(serialized_scope))
      end
      relation
    end

    def create_slug
      translations.map(&:locale).each do |locale|
        ::Mobility.with_locale(locale) { super_create_slug(locale) }
      end
    end

    def super_create_slug(locale)
      return unless friendly_id
      return if slugs.where(locale: locale).first.try(:slug) == friendly_id
      # Allow reversion back to a previously used slug
      relation = slugs.where(slug: friendly_id, locale: locale)
      if friendly_id_config.uses?(:scoped)
        relation = relation.where(:scope => serialized_scope)
      end
      relation.delete_all
      slugs.create! do |record|
        record.slug = friendly_id
        record.locale = locale
        record.scope = serialized_scope if friendly_id_config.uses?(:scoped)
      end
    end
  end
end