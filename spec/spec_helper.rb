$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'active_record'
require 'mobility'
require 'friendly_id'
require 'friendly_id/mobility'
require 'pry'

ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'

require 'database_cleaner'
DatabaseCleaner.strategy = :transaction

I18n.enforce_available_locales = false

class FriendlyIdMobilityTest < ActiveRecord::Migration
  def self.up
    create_table :journalists do |t|
      t.string  :name
      t.boolean :active
    end

    create_table :articles do |t|
    end

    create_table :mobility_string_translations do |t|
      t.string  :locale
      t.string  :key
      t.string  :value
      t.integer :translatable_id
      t.string  :translatable_type
      t.timestamps
    end

    create_table :mobility_text_translations do |t|
      t.string  :locale
      t.string  :key
      t.text    :value
      t.integer :translatable_id
      t.string  :translatable_type
      t.timestamps
    end
  end
end

class Journalist < ActiveRecord::Base
  include Mobility
  translates :slug, type: :string, fallthrough_accessors: true, backend: :key_value

  extend FriendlyId
  friendly_id :name, use: :mobility
end

class Article < ActiveRecord::Base
  include Mobility
  translates :slug, :title, type: :string, dirty: true, backend: :key_value

  extend FriendlyId
  friendly_id :title, use: :mobility
end

ActiveRecord::Migration.verbose = false
FriendlyIdMobilityTest.up

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  config.before :each do
    DatabaseCleaner.start
    I18n.locale = :en
  end

  config.after :each do
    DatabaseCleaner.clean
  end
end