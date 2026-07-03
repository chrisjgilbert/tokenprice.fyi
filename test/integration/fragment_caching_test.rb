require "test_helper"

# The model table rows and the I/O ratio widget are wrapped in <%= cache %>
# blocks (Russian-doll, backed by Solid Cache in production). These tests pin
# the correctness property: rendered output is byte-identical whether caching
# is on or off, and the cached rows still vary by sort (the highlighted column).
class FragmentCachingTest < ActionDispatch::IntegrationTest
  # Renders `url` with fragment caching turned on against a real memory store,
  # restoring the test defaults afterwards.
  def with_fragment_caching
    old_perform = ActionController::Base.perform_caching
    old_store   = ActionController::Base.cache_store
    ActionController::Base.perform_caching = true
    # The fragment cache reads/writes the *controller's* cache_store, which is
    # :null_store in test — point it at a real store so blocks actually persist.
    ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    ActionController::Base.perform_caching = old_perform
    ActionController::Base.cache_store = old_store
  end

  def body_with_caching(url)
    with_fragment_caching do
      # Prime the cache, then read through it on the second render.
      get url
      get url
      response.body
    end
  end

  def body_without_caching(url)
    get url
    response.body
  end

  # The single <tr> for the model whose name appears in it.
  def model_row(body, name)
    body.scan(%r{<tr class="clickable.*?</tr>}m).find { |tr| tr.include?(name) }
  end

  test "homepage is byte-identical with caching on vs off" do
    assert_equal body_without_caching(root_url), body_with_caching(root_url)
  end

  test "the language tab renders every language model row with caching on" do
    body = body_with_caching(root_url)
    language = ModelCategory.for("language")
    AiModel.listed.select { |m| language.member?(m.modality_class) }.each do |m|
      assert_includes body, m.name, "cached homepage is missing #{m.name}"
    end
  end

  test "the image tab renders every image model row with caching on" do
    body = body_with_caching(image_generation_url)
    image = ModelCategory.for("image")
    AiModel.listed.select { |m| image.member?(m.modality_class) }.each do |m|
      assert_includes body, m.name, "cached image tab is missing #{m.name}"
    end
  end

  test "the embeddings tab renders every embedding model row with caching on" do
    body = body_with_caching(embeddings_url)
    embeddings = ModelCategory.for("embeddings")
    AiModel.listed.select { |m| embeddings.member?(m.modality_class) }.each do |m|
      assert_includes body, m.name, "cached embeddings tab is missing #{m.name}"
    end
  end

  test "a cached row highlights the column for the CURRENT sort, not the primed one" do
    # The row markup carries a per-sort `tp-col-highlight` class, so the cache
    # key must vary by sort. Prime the store with the input sort, then request the
    # output sort over the SAME store: one specific model's row must now highlight
    # the OUTPUT cell. A sort-blind key would replay the stale input-highlighted row.
    model = ai_models(:opus)

    with_fragment_caching do
      get root_url(sort: "input", dir: "asc")   # primes the cache
      get root_url(sort: "output", dir: "asc")  # must NOT serve a stale input row
      row = model_row(response.body, model.name)
      assert row, "expected a row for #{model.name}"

      # The 1st numeric td is input, 2nd is output. Under sort=output the output
      # column (2nd) must be the highlighted one.
      numeric_classes = row.scan(/<td [^>]*class="numeric ?([a-z-]*)"/).flatten
      assert_equal "tp-col-highlight", numeric_classes[1],
        "output-sorted row must highlight the output column, not a stale input one"
      assert_equal "", numeric_classes[0],
        "the input column must not stay highlighted from the primed input sort"
    end
  end

  test "a same-day in-place price correction invalidates the cached homepage row" do
    # The row cache key must track the price point's updated_at, not effective_on:
    # a same-day correction (new value, new updated_at, SAME effective_on) must
    # bust the cached row rather than serve the stale priced figure.
    model = ai_models(:opus)

    with_fragment_caching do
      get root_url # primes the row cache
      assert_includes model_row(response.body, model.name), "$5.00",
        "fixture sanity: opus input renders as $5.00 before the correction"

      pp = model.current_price
      travel_to 1.hour.from_now do
        pp.update!(input_per_mtok: 7) # same effective_on, new updated_at
      end

      get root_url
      row = model_row(response.body, model.name)
      assert_includes row, "$7.00",
        "the corrected price must appear — the stale cached row was served"
      assert_not_includes row, "$5.00",
        "the pre-correction price must not survive in the cached row"
    end
  end

  # The io_ratio widget now lives only on /learn/reasoning, embedded with an
  # explicit `models:` local. Its cached render must be byte-identical to the
  # uncached one — the catalog load inside the cache block doesn't change output.
  test "io ratio widget page is byte-identical with caching on vs off" do
    assert_equal body_without_caching(learn_reasoning_url),
                 body_with_caching(learn_reasoning_url)
  end
end
