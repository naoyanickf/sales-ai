require "test_helper"

class DevControllerTest < ActionDispatch::IntegrationTest
  test "should get react" do
    get dev_react_url
    assert_response :success
  end
end
