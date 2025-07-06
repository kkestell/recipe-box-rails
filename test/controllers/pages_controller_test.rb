require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get help" do
    get pages_help_url
    assert_response :success
  end
end
