ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'
require 'yaml'
require 'bcrypt'

require_relative '../cms'

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = '')
    File.open(File.join(data_path, name), 'w') do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def test_index
    create_document 'about.md'
    create_document 'changes.txt'

    get '/'
    
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'about.md'
    assert_includes last_response.body, 'changes.txt'
  end

  def test_view_text_document
    create_document 'changes.txt', '2015 - Ruby 2.3 released.'

    get '/changes.txt'

    assert_equal 200, last_response.status
    assert_equal 'text/plain;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '2015 - Ruby 2.3 released.'
  end

  def test_document_not_found
    get '/notafile.ext'

    assert_equal 302, last_response.status
    assert_equal 'notafile.ext does not exist!', session[:message]
  end

  def test_render_markdown
    create_document 'about.md', '#Ruby is...'

    get '/about.md'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h1>Ruby is...</h1>'
  end

  def test_edit_links_exist
    create_document 'about.md'

    get '/'
    assert_includes last_response.body, 'Edit</a>'
  end

  def test_view_edit_page
    create_document "changes.txt"

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_view_edit_page_signed_out
    create_document "changes.txt"

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_edit_document
    post '/history.txt', { content: 'new content' }, admin_session
    assert_equal 302, last_response.status
    assert_equal 'history.txt has been updated.', session[:message]

    get '/history.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'new content'
  end

  def test_edit_document_signed_out
    create_document 'history.txt'

    post '/history.txt', content: 'new content'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_view_new_document_form
    get '/new', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<input'
    assert_includes last_response.body, '<button type="submit"'
  end

  def test_view_new_document_form_signed_out
    get '/new'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_create_new_document
    post '/new', { file_name: 'new_name.txt' }, admin_session
    assert_equal 302, last_response.status
    assert_equal 'new_name.txt has been created.', session[:message]

    get '/'
    assert_includes last_response.body, 'new_name.txt'
  end

  def test_create_new_document_signed_out
    post '/new', file_name: 'test.txt'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_create_new_document_file_extension_error
    post '/new', { file_name: 'new_name' }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'File must be of type .txt or .md.'
  end

  def test_create_new_document_no_name_error
    post '/new', { file_name: '' }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'A name is required.'
  end

  def test_delete_button_exists
    create_document 'test.txt'

    get '/'
    assert_includes last_response.body, 'Edit</a>'
  end

  def test_delete_document
    create_document 'test.txt'

    post '/test.txt/delete', {}, admin_session
    assert_equal 302, last_response.status
    assert_equal 'test.txt has been deleted.', session[:message]

    get '/'
    refute_includes last_response.body, 'href="/test.txt"'
  end

  def test_delete_document_signed_out
    create_document 'test.txt'
    
    post '/test.txt/delete'
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_view_sign_in_form
    get '/users/sign_in'
    assert_equal 200, last_response.status

    assert_includes last_response.body, '<input'
    assert_includes last_response.body, '<button type="submit"'
  end

  def test_sign_in_success
    post '/users/sign_in', username: 'admin', password: 'secret'
    assert_equal 302, last_response.status

    assert_equal 'Welcome!', session[:message]
    assert_equal 'admin', session[:username]

    get '/'
    assert_includes last_response.body, 'Sign Out</button>'
  end

  def test_sign_in_wrong_password
    post '/users/sign_in', username: 'admin', password: 'wrong'

    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, 'Invalid Credentials'
  end

  def test_sign_in_user_does_not_exist
    post '/users/sign_in', username: 'keith', password: 'doesntmatter'

    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, 'Invalid Credentials'
  end

  def test_sign_out_message
    get '/', {}, admin_session
    assert_includes last_response.body, "Signed in as admin"

    post '/users/sign_out'
    get last_response['Location']

    assert_nil session[:username]
    assert_includes last_response.body, 'You have been signed out.'
    assert_includes last_response.body, 'Sign In'
  end
end