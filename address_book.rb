require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "erb"
require "yaml"
require "bcrypt"

configure do
  set :erb, :escape_html => true
  enable :sessions
  set :session_secret, 'super secret'
end

before do
  session[:contacts] ||= []
end

def load_contact_info(contact_name)
  session[:contacts].each do |contact|
    @contact_info = contact if contact[:name] == contact_name
  end
end

def delete_preexisting_info(name)
  session[:contacts].reject! { |contact| contact[:name] == name }
end

def update_contact_info(name, phone, address, email)
  session[:contacts] << { name: name, phone: phone, address: address, email: email }
end

# returns error msg if invalid name- else returns nil
def error_for_contact_name(name)
  if !(1..100).cover? name.size
    "The contact name must be between 1 and 100 characters."
  elsif session[:contacts].any? { |contact| contact[:name] == name }
    "Contact name must be unique."
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_login?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def user_signed_in?
  session[:username]
end

def require_signed_in_user
  unless user_signed_in?
    session[:error] = "You must be signed in to do that."
    redirect '/'
  end
end

# index of all contacts
get '/' do
  @contacts = session[:contacts].sort_by { |contact| contact[:name] }
  @contacts.reverse! if params[:sort] == "desc"

  erb :home
end

# enter info for new contact
get '/new' do
  require_signed_in_user
  erb :new
end

# create new contact
post '/create' do
  require_signed_in_user
  name = params[:contact_name].strip

  error = error_for_contact_name(name)
  if error
    session[:error] = error
    status 422
    erb :new
  else
    update_contact_info(name, params[:phone], params[:address], params[:email])

    session[:success] = "The contact #{params[:contact_name]} has been added."
    redirect "/"
  end
end

# view individual contact
get '/:contact_name' do
  require_signed_in_user

  if session[:contacts].any? { |contact| contact[:name] == params[:contact_name] }
    load_contact_info(params[:contact_name])
    erb :contact
  else
    session[:error] = "#{params[:contact_name]} is not listed in your address book."
    redirect "/"
  end
end

# edit existing contact
get '/:contact_name/edit' do
  require_signed_in_user
  load_contact_info(params[:contact_name])

  erb :edit
end

# submit edited information
post '/:contact_name/edit' do
  require_signed_in_user
  delete_preexisting_info(params[:contact_name])

  update_contact_info(params[:contact_name], params[:phone], params[:address], params[:email])

  session[:success] = "#{params[:contact_name]}'s information was updated."
  redirect '/'
end

# delete individual contact
post '/:contact_name/deleted' do
  require_signed_in_user
  delete_preexisting_info(params[:contact_name])

  session[:success] = "Contact #{params[:contact_name]} deleted."
  redirect '/'
end

# user sign in screen
get '/users/signin' do
  erb :signin
end

# submit user signin info
post '/users/signin' do
  username = params[:username]

  if valid_login?(username, params[:password])
    session[:username] = username
    session[:success] = "You have been logged in. Welcome!"
    redirect '/'
  else
    session[:error] = "Invalid login."
    status 422
    erb :signin
  end
end

# sign out user
post '/users/signout' do
  session.delete(:username)

  session[:success] = "You have been logged out."
  redirect '/'
end

