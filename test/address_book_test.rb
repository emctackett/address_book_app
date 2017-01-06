ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "../address_book"

class AddressBookTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    create_contact "Ruby Jenkins"
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def create_contact(contact_name)
    get "/", {}, {"rack.session" => {contacts: [{ name: contact_name, phone: '', address: '', email: '' }] } }
  end

  def test_homepage
    get "/"

    assert_equal 200, last_response.status
    assert "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby Jenkins"
  end

  def test_viewing_contact
    get "/Ruby%20Jenkins", {}, admin_session

    assert_equal 200, last_response.status
    assert "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "<h4>Name:</h4>"
  end

  def test_viewing_contact_signed_out
    get "/Ruby%20Jenkins"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_viewing_contact_not_found
    get "/liz", {}, admin_session

    assert_equal 302, last_response.status
    assert_equal "liz is not listed in your address book.", session[:error]
  end

  def test_viewing_contact_not_found_signed_out
    get "/liz"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_editing_contact
    get "/Ruby%20Jenkins/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_editing_contact_signed_out
    get "/Ruby%20Jenkins/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_updating_contact
    post "/Ruby%20Jenkins/edit", {phone: '436-9586'}, admin_session

    assert_equal 302, last_response.status
    assert_equal "Ruby Jenkins's information was updated.", session[:success]

    get "/Ruby%20Jenkins"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "436-9586"
  end

  def test_updating_contact_signed_out
    post "/Ruby%20Jenkins/edit", {phone: '436-9586'}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_view_new_contact_form
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_view_new_contact_form_signed_out
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_create_new_contact
    post "/create", {contact_name: "Alejandro"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "The contact Alejandro has been added.", session[:success]

    get "/"
    assert_includes last_response.body, "Alejandro"
  end

  def test_create_new_contact_signed_out
    post "/create", {contact_name: "Alejandro"}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_create_new_contact_without_contact_name
    post "/create", {contact_name: ""}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "The contact name must be between 1 and 100 characters."
  end

  def test_delete_contact
    post "/Ruby%20Jenkins/deleted", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "Contact Ruby Jenkins deleted.", session[:success]
  end

  def test_delete_contact_signed_out
    post "/Ruby%20Jenkins/deleted"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_signin_form
    get '/users/signin'

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "You have been logged in. Welcome!", session[:success]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_with_bad_credentials
    post "/users/signin", username: "steve", password: "steve"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid login."
  end

  def test_signout
    get "/", {}, admin_session
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    get last_response["Location"]

    assert_nil session[:username]
    assert_includes last_response.body, "You have been logged out."
    assert_includes last_response.body, "Sign In"
  end
end