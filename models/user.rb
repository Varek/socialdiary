class User < ActiveRecord::Base

  def foursquare
    @foursquare_client = Foursquare2::Client.new(:oauth_token => self.foursquare_token)
  end

  def foursquare_checkins(date=Date.today)
    foursquare.user_checkins(afterTimestamp: date.to_datetime.to_i, beforeTimestamp: (date.to_datetime-1.seconds+1.days).to_i, sort: 'oldestfirst').items.map do |checkin|
      {type: 'foursquare_checkins', created_at: DateTime.strptime((checkin.createdAt+checkin.timeZoneOffset*60).to_s,'%s'), content: checkin.shout, venue: checkin.venue.name, photo_url: (checkin.photos.items.present? ? checkin.photos.items.first.sizes.items.first.url : nil)}
    end
  end

  def facebook
    @facebook_client ||= Koala::Facebook::API.new(self.facebook_token)
  end

  def facebook_status(date=Date.today)
    facebook.get_connections("me", 'statuses', limit: 20).select{|t| t['updated_time'].to_date == date}.reverse.map do |status|
      {type: 'facebook_status', created_at: status['updated_time'].to_datetime + 2.hours, content: status['message']}
    end
  end

  def facebook_photos(date=Date.today)
    facebook.get_connections("me", 'photos/uploaded', limit: 20).select{|t| t['created_time'].to_date == date}.reverse.map do |photo|
      {type: 'facebook_photos', created_at: photo['created_time'].to_datetime + 2.hours, caption: photo['name'], photo_url: photo['source']}
    end
    #.select{|t| t.created_at.to_date == date}
  end

  def facebook_links(date=Date.today)
    facebook.get_connections("me", 'links', limit: 20).select{|t| t['created_time'].to_date == date}.reverse.map do |link|
      {type: 'facebook_links', created_at: link['created_time'].to_datetime + 2.hours, link: link['link'], link_name: link['name'],link_description: link['description'], message: link['message']}
    end
    #.select{|t| t.created_at.to_date == date}
  end

  def eyeem
    if @eyeem_client.blank?
      EyeEmConnector.configure do |config|
        config.client_id = ENV['EYEEM_KEY']
        config.client_secret = ENV['EYEEM_SECRET']
        config.access_token = self.eyeem_token
      end
      @eyeem_client ||= EyeEmConnector
    else
      @eyeem_client
    end
  end

  def eyeem_photos(date=Date.today)
    eyeem.user_photos('me',limit: 20, detailed: true)['photos']['items'].select{|t| Date.parse(t['updated']) == date}.reverse.map {|photo|
      {type: 'eyeem_photo', created_at: DateTime.parse(photo['updated']), caption: photo['caption'], photo_url: photo['photoUrl']}}
    #.select{|t| t.created_at.to_date == date}

  end

  def twitter
    @twitter_client ||= Twitter.configure do |config|
      config.consumer_key = ENV['TWITTER_KEY']
      config.consumer_secret = ENV['TWITTER_SECRET']
      config.oauth_token = self.twitter_token
      config.oauth_token_secret = self.twitter_secret
    end
  end

  def tweets(date=Date.today)
    twitter.user_timeline(:count => 50).select{|t| t.created_at.to_date == date}.reverse.map do |tweet|
        tweet_content = tweet.text
        tweet.urls.each {|w| tweet_content.gsub!(w.url,"<a shape='rect' href='#{w.expanded_url}'>#{w.display_url}</a>")}
        {type: 'tweet', created_at: tweet.created_at.to_datetime, content: tweet_content}
      end
  end

  def evernote
    @client ||= EvernoteOAuth::Client.new(token: self.evernote_token, consumer_key:ENV['EVERNOTE_KEY'], consumer_secret:ENV['EVERNOTE_SECRET'], sandbox: true)
  end

  def note_store
    evernote.note_store
  end

  def notebook
    @notebook ||= note_store.getNotebook(self.notebook_guid) if self.notebook_guid.present?
    if @notebook.blank?
      notebook = Evernote::EDAM::Type::Notebook.new
      notebook.name = 'majic'
      @notebook = note_store.try(:createNotebook,notebook)
      self.update_attribute(:notebook_guid, @notebook.guid)
      @notebook
    end
  end

  def current_stacked_notebook
    @stacked_notebook ||= note_store.getNotebook(self.current_stacked_notebook_guid)
  end

  def create_current_stacked_notebook(date=Date.today)
    stacked_notebook = Evernote::EDAM::Type::Notebook.new
    stacked_notebook.name = date.strftime("%B %Y")
    stacked_notebook.stack = 'majic'
    @stacked_notebook = note_store.try(:createNotebook,stacked_notebook)
    self.update_attribute(:current_stacked_notebook_guid, @stacked_notebook.guid)
    @stacked_notebook
  end

  def stacked_notebook(date=Date.today)
    if self.last_diary_created_at.blank? || (date.month - self.last_diary_created_at.month) == 1
      if self.current_stacked_notebook_guid.blank?
        create_current_stacked_notebook(date)
      else
        current_stacked_notebook
      end
    else
      current_stacked_notebook
    end
  end

  def activities(date=Date.today)
    all = self.tweets(date) + self.eyeem_photos(date) + self.facebook_status(date) + self.facebook_photos(date)+ self.foursquare_checkins(date) + self.facebook_links(date)
    #binding.remote_pry
    all.sort_by { |hsh| time = Time.new(2013,4,7,hsh[:created_at].hour,hsh[:created_at].min) }
  end

  def render_social_activity(date=Date.today)
    request = Rack::MockRequest.new(Sinatra::Application)
    request.get('/diary',:params => "date=#{date}&activities=#{self.activities(date).to_json}").body
  end

  def store_diary(date)
    note = Evernote::EDAM::Type::Note.new
    note.title = date.strftime("%a, %d")
    note.notebookGuid = stacked_notebook(date).guid
    note.content = render_social_activity(date)
    #created_note = note_store.createNote(note)
    begin
      created_note = note_store.createNote(note)
    rescue => e
      puts e.inspect
    end

    self.update_attribute(:last_diary_created_at, date)
  end

  def clear
    self.notebook_guid = nil
    self.current_stacked_notebook_guid = nil
    self.last_diary_created_at = nil
    self.save
  end
end