ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

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

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_view_file_contents
    create_document "changes.txt", "2015 - Ruby 2.3 released."

    get "/changes.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "2015 - Ruby 2.3 released."
  end

  def test_document_not_found
    get '/notafile.ext'

    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "notafile.ext does not exist"

    get '/'
    assert_equal 200, last_response.status
    refute_includes last_response.body, "notafile.ext does not exist"
  end

  def test_render_markdown
    create_document "about.md", "#Ruby is..."
    get '/about.md'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_edit_links_exist
    create_document "about.md"

    get '/'
    assert_includes last_response.body, "Edit</a>"
  end

  def test_edit_document
    create_document "history.txt"

    get '/history.txt/edit'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, '<button type="submit"'
  end

  def test_update_document  
    post '/history.txt', content: "new content"

    assert_equal 302, last_response.status

    get last_response["Location"]
    
    assert_includes last_response.body, "history.txt has been updated"

    get '/history.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end
end