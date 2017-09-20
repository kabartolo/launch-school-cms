require 'redcarpet'
require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

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
    render_markdown(contents)
  when '.txt'
    content_type 'text/plain'
    contents
  end
end

def data_path
  if ENV["RACK_PATH"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

get '/' do
  pattern = File.join(data_path, '*')
  @directory = Dir.glob(pattern).map { |path| File.basename(path) }
  erb :index
end

get '/:file_name/edit' do
  file_path = File.join(data_path, params[:file_name])
  @file_name = params[:file_name]

  @content = File.read(file_path)
  erb :edit
end

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

post '/:file_name' do
  new_content = params[:content]
  file_path = File.join(data_path, params[:file_name])
  file_name = params[:file_name]

  File.write(file_path, new_content)

  session[:message] = "#{file_name} has been updated"
  redirect '/'
end
