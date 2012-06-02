after "deploy:setup", "mediawiki:setup"

namespace :mediawiki do
  desc "Setup mediawiki initializer and app configuration"
  task :setup, roles: :app do
    run "mkdir -p #{shared_path}/config"
    template "mediawiki.rb.erb", mediawiki_config
    template "mediawiki_init.erb", "/tmp/mediawiki_init"
    run "chmod +x /tmp/mediawiki_init"
    run "#{sudo} mv /tmp/mediawiki_init /etc/init.d/mediawiki_#{application}"
    run "#{sudo} update-rc.d -f mediawiki_#{application} defaults"
  end

  %w[start stop restart].each do |command|
    desc "#{command} mediawiki"
    task command, roles: :app do
      run "service mediawiki_#{application} #{command}"
    end
    after "deploy:#{command}", "mediawiki:#{command}"
  end
end
