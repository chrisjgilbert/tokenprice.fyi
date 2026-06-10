require "test_helper"

class OpenRouterSyncJobTest < ActiveJob::TestCase
  test "perform runs the model sync" do
    calls = 0
    original = OpenRouter::ModelSync.singleton_class.instance_method(:call)
    OpenRouter::ModelSync.define_singleton_method(:call) { |*, **| calls += 1 }

    begin
      OpenRouterSyncJob.perform_now
    ensure
      OpenRouter::ModelSync.singleton_class.define_method(:call, original)
    end

    assert_equal 1, calls, "expected the job to invoke OpenRouter::ModelSync.call once"
  end
end
