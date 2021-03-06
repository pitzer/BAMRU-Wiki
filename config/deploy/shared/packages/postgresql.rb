Capistrano::Configuration.instance(:must_exist).load do

  before "deploy:setup",    "postgresql:create_user"
  before "deploy:migrate",  "postgresql:create_db"

  namespace :postgresql do

    desc "Create a database user for this application."
    task :create_user, roles: :db, only: {primary: true} do
      #run %Q{#{sudo} -u postgres psql -c "create user #{app_name} with password '#{POSTGRES_PASS}' login createdb;"}
      run <<-END
        user_token=`#{sudo} -u postgres psql -c 'select usename from pg_user;' | grep #{app_name}` ;
        if [ ! $user_token ] ; then
          #{sudo} -u postgres psql -c "create user #{app_name} with password '#{POSTGRES_PASS}' login createdb;" ;
        fi
      END
    end

    desc "Create databases."
    task :create_db, roles: :db, only: {primary: true} do
      run "cd #{release_path} && rake db:create:all"
    end

  end

end
