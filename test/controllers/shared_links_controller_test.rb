require "test_helper"

class SharedLinksControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get shared_links_show_url
    assert_response :success
  end
end
