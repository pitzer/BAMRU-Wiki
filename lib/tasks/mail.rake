require 'carrier_queue'
require 'rake_util'

include RakeUtil

# ----- Utilities for Rake Tasks -----

def check_host_and_run_frequency
  file = "tmp/mail_sync_time.txt"
  if ENV['ONLY_ON'] && ENV['ONLY_ON'] != ENV['SYSNAME']
    puts "Exiting: command runs only on #{ENV["ONLY_ON"]}"
    exit
  end
  if File.exists?(file)
    if last_update_less_than_two_minutes_ago(file)
      puts "Exiting: last mail sync was less than two minutes ago."
      exit
    end
  end
  File.open(file, 'w') { |f| f.puts Time.now.strftime("%m-%d %H:%M:%S") }
end

# ----- Methods for Importing Mail -----

def last_update_less_than_two_minutes_ago(file)
  (Time.now - File.new(file).mtime) < (60 * 2)
end

def get_all_emails_from_gmail
  Time.zone = "Pacific Time (US & Canada)"
  gm = Gmail.new(GMAIL_USER, GMAIL_PASS)
  gm.inbox.emails.each do |email|
    puts "Caching mail #{email.uid}"
    STDOUT.flush
    write_email_to_disk(email)
    email.archive!
  end
  gm.logout
end

def mail_dir
  dir = Rails.root.to_s + "/tmp/inbound_mails"
  system "mkdir -p #{dir}"
  dir
end

def write_email_to_disk(mail)
  mail_file = "#{mail_dir}/#{Time.now.strftime("inbound_%y%m%d_%H%M%S")}.yaml"
  opts = {}
  opts[:subject]   = mail.subject
  opts[:from]      = mail.from.join(' ')
  opts[:to]        = mail.to.join(' ')
  opts[:uid]       = mail.try(:uid)
  opts[:body]      = mail.body.to_s.lstrip
  opts[:send_time] = mail.date.to_s
  File.open(mail_file, 'w') {|f| f.puts opts.to_yaml }
end

def load_all_emails_into_database
  cmd = curl_get("api/rake/messages/load_inbound")
  puts "Loading emails into database..."
  system cmd
end

# ----- Method for sending mail -----

def render_email_message(opts, format)
  case format
    when 'page'              then Notifier.page_email(opts)
    when 'password_reset'    then Notifier.password_reset_email(opts)
    when 'do_shift_pending'  then Notifier.do_shift_pending_email(opts)
    when 'do_shift_starting' then Notifier.do_shift_starting_email(opts)
    when 'cert_notice'       then Notifier.cert_notice_email(opts)
    else nil
  end
end

def render_phone_message(opts, format)
  case format
    when 'page'              then Notifier.page_phone(opts)
    when 'do_shift_starting' then Notifier.do_shift_starting_phone(opts)
    else nil
  end
end

def render_mail(outbound_mail)
  puts "rendering message for #{outbound_mail.address}"
  STDOUT.flush
  yaml_file = "/tmp/render_msg/#{outbound_mail.id}_#{outbound_mail.label}"
  return if File.exists?(yaml_file)
  mailing    = nil
  message    = outbound_mail.distribution.message
  address    = outbound_mail.email_address
  full_label = outbound_mail.full_label
  dist       = outbound_mail.distribution
  format     = message.format
  opts       = Notifier.set_optz(message, address, full_label, dist)
  mailing    = render_email_message(opts, format) if outbound_mail.email
  mailing    = render_phone_message(opts, format) if outbound_mail.phone
  unless mailing.nil?
    File.open(yaml_file, 'w') {|f| f.puts mailing.to_yaml}
  end
end

def send_mail(outbound_mail)
  puts "sending to #{outbound_mail.address}"
  STDOUT.flush
  mailing    = nil
  message    = outbound_mail.distribution.message
  address    = outbound_mail.email_address
  full_label = outbound_mail.full_label
  dist       = outbound_mail.distribution
  format     = message.format
  opts       = Notifier.set_optz(message, address, full_label, dist)
  mailing    = render_email_message(opts, format) if outbound_mail.email
  mailing    = render_phone_message(opts, format) if outbound_mail.phone
  unless mailing.nil?
    mailing.deliver
    invoke_url = "api/rake/messages/#{outbound_mail.id}/sent_at_now.json?update=true"
    cmd        = curl_get(invoke_url)
    system cmd
  end
end

# ----- Rake Tasks -----

namespace :ops do
  namespace :email do

    namespace :pending do

      desc "Count Pending Mails"
      task :count => 'environment' do
        count = OutboundMail.pending.count
        puts "Pending Outbound Mails: #{count}"
        STDOUT.flush
      end

      desc "Render Pending Mails"
      task :render => [:environment, :update_sent_at] do
        system "mkdir -p /tmp/render_msg; rm -f /tmp/render_msg/*"
        Time.zone  = "Pacific Time (US & Canada)"
        mails      = OutboundMail.pending.all
        if mails.count > 0
          invoke_url = "api/rake/messages/render_notice?label=started&count=#{mails.count}"
          cmd        = curl_get(invoke_url)
          puts "Started Rendering"
          system cmd
          mails.each { |om| render_mail(om) }
          invoke_url = "api/rake/messages/render_notice?label=finished&count=#{mails.count}"
          cmd        = curl_get(invoke_url)
          system cmd
          puts "Finished Rendering"
          STDOUT.flush
        end
      end

      desc "Send Pending Mails"
      task :send => :environment do
        Time.zone = "Pacific Time (US & Canada)"
        send_list = CarrierQueueCollection.new
        mails     = OutboundMail.pending.all
        mails.each { |om| send_list.add(om) }
        while send_obj = send_list.get
          send_mail(send_obj)
        end
        STDOUT.flush
      end

      desc "Send Pending Mails V2"
      task :send2 => [:environment, :render] do
        require 'yaml'
        Time.zone = "Pacific Time (US & Canada)"

        tdate = Time.now.strftime("%y%m%d_%H%M%S")

        Dir.glob("/tmp/render_msg/*").each do |file|
          mail_attributes = YAML.load_file(file)
          mail = ActionMailer::Base.mail(mail_attributes)
          mail.subject = mail_attributes["Subject"]
          outbound_mail_id = file.split('/').last.split('_').first
          debugger
          puts "sending message #{outbound_mail_id} (#{mail.to.first})"
          smtp_settings = [:smtp, SMTP_SETTINGS]
          mail.delivery_method(*smtp_settings) if Rails.env.production?
          mail.deliver

          unless outbound_mail_id.blank?
            system "mkdir -p /tmp/sent_at"

            invoke_url = "api/rake/messages/#{outbound_mail_id}/sent_at_now.json"
            cmd        = curl_get(invoke_url)
            system cmd

            File.open("/tmp/sent_at/#{tdate}", "a") do |f|
              f.puts "#{outbound_mail_id}|#{Time.now}"
            end

          end
          system "rm -f #{file}"
          sleep 0.25
        end
        Rake::Task['ops:email:pending:update_sent_at'].execute
      end

      desc "Update email sent at"
      task :update_sent_at do
        Dir.glob("/tmp/sent_at/*").each do |file|
          puts "Recording data values from #{file}"
          data       = File.read(file)
          invoke_url = "api/rake/messages/update_sent_at"
          cmd        = curl_post(invoke_url, data)
          value      = `#{cmd}`
          system "rm -f #{file}" if value[0..1] == "OK"
          sleep 1
        end
      end

    end

    # ----- Inbound Pager Messages -----

    desc "Load inbound emails from our gmail account"
    task :import => 'environment' do
      check_host_and_run_frequency
      get_all_emails_from_gmail
      load_all_emails_into_database
    end

    namespace :generate do

      # ----- Password Reset -----

      desc "Password Reset ADDRESS=<email_address>"
      task :password_reset => :environment do
        adr = ENV["ADDRESS"]
        cmd = curl_get("api/rake/password/reset?address=#{adr}")
        puts "Generating password reset mail for #{adr} at #{Time.now}"
        system cmd
      end

      # ----- DO Mails -----

      # sent 4 days before the shift starts
      desc "DO Shift Pending Reminder"
      task :do_shift_pending => :environment do
        cmd = curl_get('api/rake/reminders/do_shift_pending')
        puts "Generating DO Shift Pending Reminder"
        system cmd
      end

      # sent 1 hours before the shift starts
      desc "DO Shift Starting Alert"
      task :do_shift_starting => 'environment' do
        cmd = curl_get('api/rake/reminders/do_shift_starting')
        puts "Generating DO Shift Starting Reminder"
        system cmd
      end

      # ----- Cert Reminder Mails -----

      desc "Cert Expiration Notices"
      task :cert_notices => 'environment' do
        cmd = curl_get('api/rake/reminders/cert_expiration')
        puts "Generating Cert Expiration Notice"
        system cmd
      end

    end
  end
end
