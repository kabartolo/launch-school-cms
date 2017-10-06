require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file(path)
  contents = File.read(path)

  case File.extname(path)
  when '.md'
    erb render_markdown(contents)
  when '.txt'
    content_type 'text/plain'
    contents
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def user_credentials_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
end

def new_file_error(name)
  path = "#{data_path}/#{name}"
  if name.empty?
    "A name is required."
  elsif File.extname(path) != '.txt' && File.extname(path) != '.md'
    "File must be of type .txt or .md."
  end
end

def user_signed_in?
  session.key?(:username)
end

def deny_access
  session[:message] = "You must be signed in to do that."
  redirect '/' 
end

def valid_user?(username, password)
  data = YAML.load_file(user_credentials_path)

  if data.key?(username)
    bcrypt_password = BCrypt::Password.new(data[username])
    bcrypt_password == password
  else
    false
  end
end

# Render the index page
get '/' do
  pattern = File.join(data_path, '*')
  @directory = Dir.glob(pattern).map { |path| File.basename(path) }
  erb :index
end

get '/users/sign_in' do
  erb :sign_in
end

post '/users/sign_in' do
  username = params[:username]
  password = params[:password]

  if valid_user?(username, password)
    session[:username] = username
    session[:message] = 'Welcome!'
    redirect '/'
  else
    session[:message] = 'Invalid Credentials'
    status 422
    erb :sign_in
  end
end

post '/users/sign_out' do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect '/'
end

# Render the new-document form
get '/new' do
  deny_access unless user_signed_in?

  erb :new
end

# Create a new document
post '/new' do
  deny_access unless user_signed_in?

  file_name = params[:file_name].to_s

  error = new_file_error(file_name)
  if error
    session[:message] = error
    status 422
    erb :new
  else
    file_path = File.join(data_path, file_name)

    File.write(file_path, "")
    session[:message] = "#{file_name} has been created."

    redirect '/'
  end
end

# View edit page
get '/:file_name/edit' do
  deny_access unless user_signed_in?

  file_path = File.join(data_path, params[:file_name])
  @file_name = params[:file_name]

  @content = File.read(file_path)
  erb :edit
end

# Update file
post '/:file_name' do
  deny_access unless user_signed_in?

  new_content = params[:content]
  file_name = params[:file_name]
  file_path = File.join(data_path, file_name)

  File.write(file_path, new_content)

  session[:message] = "#{file_name} has been updated."
  redirect '/'
end

# Render the file contents
get '/:file_name' do
  file_name = params[:file_name]
  file_path = File.join(data_path, params[:file_name])

  if File.exists?(file_path)
    load_file(file_path)
  else
    session[:message] = "#{file_name} does not exist!"
    redirect '/'
  end
end

post '/:file_name/delete' do
  deny_access unless user_signed_in?

  file_name = params[:file_name]
  file_path = File.join(data_path, file_name)

  File.delete(file_path)

  session[:message] = "#{file_name} has been deleted."
  redirect '/'
end
