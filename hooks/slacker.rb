require 'etc'
require 'rest-client'
require 'json'
require 'yaml'
require 'etc'

module Slacker

  def self.included(klass)
    unless File.exists?('hooks/config.yaml')
      puts "no config"
      exit 255
    end
    config = YAML.load_file('hooks/config.yaml')
    @@webhook = config["webhook"]
    @@user = Etc.getlogin

    gitout = `git remote show origin 2>&1`
    @@project = gitout[/#{"Fetch URL: "}(.*?)#{"\n"}/m, 1].split("/")[-1]
  end


  def send_slack(themessage)
    return if @@webhook.nil? || @@webhook.empty?
    request = RestClient::Request.new(
      :method => "POST",
      :url => @@webhook,
      :payload => themessage.to_json
    )
    begin
      response = request.execute
    rescue Exception => e
      puts e
    end
  end


  def send_complete(tag)
    message = {
      :attachments => [
        {
          :color => "good",
          :title => "Deployment Complete",
          :pretext => "LEM Deployment Notification",
          :mrkdwn_in => [ "text" ]
        }
      ]
    } 
    message[:attachments][0][:fallback] = "#{@@user} successfully deployed #{@@project}"
    message[:attachments][0][:text] = "LEM _successfully_ completed a deployment"
    message[:attachments][0][:fields] = [{:title => "Application", :value => @@project, :short => true}, {:title => "Deployed By:", :value => @@user, :short => true},{:title => "Release", :value => tag, :short => false }]
    send_slack(message)
  end


  def send_fail(tag, stage, error)
    message = {
      :attachments => [
        {
          :color => "danger",
          :title => "Deployment *FAILED*",
          :pretext => "LEM Deployment Notification",
          :mrkdwn_in => [ "text", "title" ]
        }
      ]
    }
    message[:attachments][0][:fallback] = "#{@@user}'s deployment of #{@@project} failed"
    message[:attachments][0][:text] = "LEM _failed_ to complete a deployment"
    message[:attachments][0][:fields] = [{:title => "Application", :value => @@project, :short => true}, {:title => "Deployed By:", :value => @@user, :short => true},{:title => "Release", :value => tag, :short => false }, {:title => "Failed in Stage", :value => stage, :short => false}, {:title => "Error", :value => error, :short => false}]
    send_slack(message)
  end


  def send_rollback(tag)
    message = {
      :attachments => [
        {
          :color => "warning",
          :title => "Deployment rolled back",
          :pretext => "LEM Deployment Notification",
          :mrkdwn_in => [ "text", "title" ]
        }
      ]
    }
    message[:attachments][0][:fallback] = "#{@@user} rolled back a  deployment of #{@@project}"
    message[:attachments][0][:text] = "LEM _rolled back_ a deployment"
    message[:attachments][0][:fields] = [{:title => "Application", :value => @@project, :short => true}, {:title => "Rolled Back By:", :value => @@user, :short => true},{:title => "Withdrawn Release", :value => tag, :short => false }]
    send_slack(message)
  end
end
