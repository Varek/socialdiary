require 'rubygems'
require 'sinatra'
require "sinatra/reloader" if development?
require 'json'
require 'multi_json'
require 'omniauth'
require 'omniauth-evernote'
require 'omniauth-facebook'
require 'omniauth-twitter'

class SinatraApp < Sinatra::Base
  configure do
    set :sessions, true
    set :inline_templates, true
  end
  use OmniAuth::Builder do
    provider :evernote, ENV['EVERNOTE_KEY'], ENV['EVERNOTE_SECRET'], :client_options => { :site => 'https://sandbox.evernote.com' }
    provider :facebook, ENV['FACEBOOK_KEY'], ENV['FACEBOOK_SECRET']
    provider :twitter, ENV['TWITTER_KEY'], ENV['TWITTER_SECRET']

  end

  get '/' do
    erb "
    <a href='http://localhost:5000/auth/evernote'>Login with Evernote</a><br>
    <a href='http://localhost:5000/auth/facebook'>Login with Facebook</a><br>
    <a href='http://localhost:5000/auth/twitter'>Login with Twitter</a><br>"
  end

  get '/auth/:provider/callback' do
    erb "<h1>#{params[:provider]}</h1>
         <pre>#{JSON.pretty_generate(request.env['omniauth.auth'])}</pre>"
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

  get '/logout' do
    session[:authenticated] = false
    redirect '/'
  end

end

SinatraApp.run! if __FILE__ == $0

__END__

@@ layout
<html>
  <head>
    <link href='http://twitter.github.com/bootstrap/1.4.0/bootstrap.min.css' rel='stylesheet' />
  </head>
  <body>
    <div class='container'>
      <div class='content'>
        <%= yield %>
      </div>
    </div>
  </body>
</html>
