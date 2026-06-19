require "test_helper"

class Admin::ProvidersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_admin }

  test "index lists providers" do
    get admin_providers_path
    assert_response :success
    assert_select "th[scope=row]", /Anthropic/
  end

  test "creates a provider with an auto slug" do
    assert_difference "Provider.count", 1 do
      post admin_providers_path, params: { provider: { name: "Cohere", website: "https://cohere.com" } }
    end
    assert Provider.exists?(slug: "cohere")
  end

  test "persists the headquarters country" do
    post admin_providers_path, params: { provider: { name: "Cohere", country: "Canada", country_code: "ca" } }
    cohere = Provider.find_by!(slug: "cohere")
    assert_equal "Canada", cohere.country
    assert_equal "CA", cohere.country_code
  end

  test "won't delete a provider that still has models" do
    assert_no_difference "Provider.count" do
      delete admin_provider_path(providers(:anthropic))
    end
    assert_redirected_to admin_providers_path
  end

  test "deletes an empty provider" do
    empty = Provider.create!(name: "Empty Co")
    assert_difference "Provider.count", -1 do
      delete admin_provider_path(empty)
    end
  end

  test "the slug is locked on update" do
    patch admin_provider_path(providers(:anthropic)),
          params: { provider: { slug: "hijacked", name: "Anthropic Renamed" } }
    assert_redirected_to admin_providers_path
    anthropic = providers(:anthropic).reload
    assert_equal "anthropic", anthropic.slug      # unchanged
    assert_equal "Anthropic Renamed", anthropic.name # other fields still update
  end
end
