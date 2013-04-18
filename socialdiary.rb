require 'rubygems'
require 'sinatra'
require "sinatra/reloader" if development?
require 'sinatra/activerecord'
require 'active_support/all'
require 'json'
require 'multi_json'
require 'omniauth'
require 'omniauth-evernote'
require 'omniauth-facebook'
require 'omniauth-twitter'
require 'omniauth-foursquare'
require 'omniauth-eyeem'
require 'pry-remote'
require 'twitter'
require 'evernote_oauth'
require 'evernote-thrift'
require 'faraday'
require 'faraday_middleware'
require 'EyeEmConnector'
require 'koala'
require 'foursquare2'


require './models/user'
require './config/environments'

configure do
  set :sessions, true
  set :session_secret, "majic"
  set :inline_templates, true

  use OmniAuth::Builder do
    provider :evernote, ENV['EVERNOTE_KEY'], ENV['EVERNOTE_SECRET'], :client_options => { :site => 'https://sandbox.evernote.com' }
    provider :facebook, ENV['FACEBOOK_KEY'], ENV['FACEBOOK_SECRET'], :scope => 'user_photos,user_status', :display => 'popup'
    provider :twitter, ENV['TWITTER_KEY'], ENV['TWITTER_SECRET']
    provider :foursquare, ENV['FOURSQUARE_KEY'], ENV['FOURSQUARE_SECRET']
    provider :eyeem, ENV['EYEEM_KEY'], ENV['EYEEM_SECRET']
  end
end

before do
  @user = User.find_by_evernote_id(session['user_id']) if session['user_id'].present?
  #@access_token = session['access_token']
  #@client_id = ENV['CLIENT_ID']
  #@client_secret = ENV['CLIENT_SECRET']
  #@redirect_uri = ENV['REDIRECT_URI']
end

get '/' do
  erb :home
end

get '/auth/:provider/callback' do
  session['auth_data'] = request.env['omniauth.auth']
  case request.env['omniauth.auth']['provider']
  when 'evernote'
    @user = User.find_or_create_by_evernote_id(request.env['omniauth.auth']['uid'])
    @user.update_attribute(:evernote_token,request.env['omniauth.auth']['credentials']['token'])
    session['user_id'] = @user.evernote_id

  when 'twitter'
    @user.update_attributes(twitter_token: request.env['omniauth.auth']['credentials']['token'],
      twitter_id: request.env['omniauth.auth']['uid'],
      twitter_secret: request.env['omniauth.auth']['credentials']['secret'])
  when 'facebook'
    @user.update_attributes(facebook_token: request.env['omniauth.auth']['credentials']['token'],
          facebook_id: request.env['omniauth.auth']['uid'])
  when 'foursquare'
    @user.update_attributes(foursquare_token: request.env['omniauth.auth']['credentials']['token'])
  when 'eyeem'
    @user.update_attributes(eyeem_token: request.env['omniauth.auth']['credentials']['token'])
  end
  redirect '/services'
end

get '/services' do
  erb :services
end

get '/auth/failure' do
  erb "<h1>Authentication Failed:</h1><h3>message:<h3> <pre>#{params}</pre>"
end

get '/auth/:provider/deauthorized' do
  erb "#{params[:provider]} has deauthorized this app."
end

get '/protected' do
  throw(:halt, [401, "Not authorized\n"]) unless session[:authenticated]
  erb "<pre>#{request.env['omniauth.auth'].to_json}</pre><hr>
       <a href='/logout'>Logout</a>"
end

get '/diary' do
  if params[:activities].present?
    @activities = MultiJson.decode(params[:activities], symbolize_keys: true)
    @activities.each{|a| a[:created_at] = DateTime.parse(a[:created_at])}
  else
    @activities = @user.activities(Date.today)
  end
  @date = if params[:date].present?
    Date.parse(params[:date])
  else
    Date.today
  end
  erb :diary, layout: false
end

get '/logout' do
  session[:authenticated] = false
  redirect '/'
end