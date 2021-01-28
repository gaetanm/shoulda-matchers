require 'acceptance_spec_helper'

describe 'shoulda-matchers integrates with active record' do
  before do
    create_active_record_project

    write_file 'db/migrate/1_create_users.rb', <<-FILE
      class CreateUsers < #{migration_class_name}
        def self.up
          create_table :users do |t|
          end
        end
      end
    FILE

    write_file 'db/migrate/2_create_profiles.rb', <<-FILE
      class CreateProfiles < #{migration_class_name}
        def self.up
          create_table :profiles do |t|
            t.references :user, null: false, foreign_key: true
          end
        end
      end
    FILE

    write_file 'Rakefile', <<-FILE
      require 'active_record'
      require 'sqlite3'

      namespace :db do
        desc 'Create the database'
        task :create do
          SQLite3::Database.new 'db/test.sqlite3'
        end

        desc 'Migrate the database'
        task :migrate do
          ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'db/test.sqlite3')
          ActiveRecord::Migrator.migrations_paths = ['db/migrate']
          ActiveRecord::Tasks::DatabaseTasks.migrate
        end
      end
    FILE

    run_rake_tasks!('db:create', 'db:migrate')

    write_file 'lib/user.rb', <<-FILE
      require 'active_record'

      class User < ActiveRecord::Base
      end
    FILE

    write_file 'lib/profile.rb', <<-FILE
      require 'active_record'
      require 'user'

      class Profile < ActiveRecord::Base
        belongs_to :user
        validates_presence_of :user
      end
    FILE

    write_file 'spec/profile_spec.rb', <<-FILE
      require 'spec_helper'
      require 'profile'

      describe Profile do
        before do
          ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'db/test.sqlite3')
        end

        it { should validate_presence_of(:user) }
      end
    FILE

    updating_bundle do
      add_rspec_to_project
      add_shoulda_matchers_to_project(
        manually: true,
        with_configuration: false,
      )
      write_file 'spec/spec_helper.rb', <<-FILE
        require 'shoulda/matchers'

        RSpec.configure do |config|
          config.include(Shoulda::Matchers::ActiveModel)
        end
      FILE
    end
  end

  context 'when using both active_record and active_model libraries' do
    it 'allows the use of matchers from both libraries' do
      result = run_rspec_tests('spec/profile_spec.rb')

      expect(result).to have_output('1 example, 0 failures')
      expect(result).to have_output(
        'is expected to validate that :user cannot be empty/falsy',
      )
    end
  end
end
