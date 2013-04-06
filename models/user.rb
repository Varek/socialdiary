class User < ActiveRecord::Base

  def tweets(date=Date.today)
    Twitter.configure do |config|
      config.consumer_key = ENV['TWITTER_KEY']
      config.consumer_secret = ENV['TWITTER_SECRET']
      config.oauth_token = self.twitter_token
      config.oauth_token_secret = self.twitter_secret
    end
    Twitter.user_timeline(:count => 50).select{|t| t.created_at.to_date == date}.reverse.map do |tweet|
        {type: 'tweet', created_at: tweet.created_at, content: tweet.text}
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

  def render_social_activity(date=Date.today)
    request = Rack::MockRequest.new(Sinatra::Application)
    activities = self.tweets(date).to_json
    request.get('/diary',:params => "date=#{date}&activities=#{activities}").body
  end

  def store_diary(date)
    note = Evernote::EDAM::Type::Note.new
    note.title = date.strftime("%a, %d")
    note.notebookGuid = stacked_notebook(date).guid
    note.content = render_social_activity(date)
    created_note = note_store.createNote(note)
    self.update_attribute(:last_diary_created_at, date)
  end

  def clear
    self.notebook_guid = nil
    self.current_stacked_notebook_guid = nil
    self.last_diary_created_at = nil
    self.save
  end
end