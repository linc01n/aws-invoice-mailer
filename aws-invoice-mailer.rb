#!/usr/bin/env ruby

require 'rubygems'
require 'Mechanize'
require 'action_mailer'
require 'yaml'

settings = YAML::load_file("settings.yml")
last_month = (Date.today << 1).strftime("%Y_%m")
file_name = last_month +"_aws_invoice.pdf"

agent = Mechanize.new
agent.get("https://portal.aws.amazon.com/gp/aws/developer/account/index.html?ie=UTF8&action=activity-summary")
form = agent.page.forms.first
form.email = settings["aws_login_email"]
form.password = settings["aws_login_password"]
form.submit
agent.page.links_with(:text => "View Full Statement").first.click
agent.get(agent.page.links_with(:class => "invoiceLink").first.href).save(file_name)

ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
  :address => settings["mail"]["server"], # your email server here
  :port => settings["mail"]["port"],
  :domain => settings["mail"]["domain"],
  :authentication => :plain,
  :user_name => settings["mail"]["username"],
  :password => settings["mail"]["password"],
  :enable_starttls_auto => true
}

class InvoiceMailer < ActionMailer::Base
  default :from => "abc@abc.com",
          :reply_to => "def@abc.com",
          :charset => "UTF-8"
  def mail_invoice(opts = {})
    @nick = opts[:nick]
    opts[:files].each{ |file|
      attachments[file] = {:content_disposition => "attachment;filename="+file, :mime_type => 'application/pdf', :content => File.read(file)}
    }
    mail(:to => opts[:to], :subject => opts[:subject], :cc => opts[:cc] ) do |format|
      format.text { render :text => 'Render text' }
      format.html {
        render "invoice_mailer/invoice"
      }
    end
  end
end

InvoiceMailer.mail_invoice({:nick => settings["email_settings"]["recipient_name"], :files => [file_name], :to => settings["email_settings"]["to"], :subject => settings["email_settings"]["subject"], :cc => settings["email_settings"]["cc"] }).deliver

