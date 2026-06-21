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

  test "homepage still renders every expected model row with caching on" do
    body = body_with_caching(root_url)
    AiModel.listed.find_each do |m|
      assert_includes body, m.name, "cached homepage is missing #{m.name}"
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
      numeric_classes = row.scan(/<td class="numeric ?([a-z-]*)"/).flatten
      assert_equal "tp-col-highlight", numeric_classes[1],
        "output-sorted row must highlight the output column, not a stale input one"
      assert_equal "", numeric_classes[0],
        "the input column must not stay highlighted from the primed input sort"
    end
  end

  test "io ratio widget page is byte-identical with caching on vs off" do
    assert_equal body_without_caching(how_pricing_works_url),
                 body_with_caching(how_pricing_works_url)
  end

  # The widget is embedded on /learn/anatomy with an explicit `models:` local,
  # and on /how-pricing-works with the default (lazy-loaded) catalog. Both paths
  # must render byte-identically with caching on vs off — proving the catalog
  # load moved inside the cache block didn't change output and the key still
  # discriminates the model set passed via the local.
  test "io ratio widget with an explicit models local is byte-identical cached vs not" do
    assert_equal body_without_caching(learn_anatomy_url),
                 body_with_caching(learn_anatomy_url)
  end

  # Counts PriceCatalog.models invocations across the block, with the override
  # neutralized afterwards so it can't leak into later tests.
  def counting_price_catalog_models
    calls = 0
    counting = Module.new do
      define_method(:models) { calls += 1; super() }
    end
    PriceCatalog.singleton_class.prepend(counting)
    begin
      yield -> { calls }
    ensure
      counting.send(:define_method, :models) { super() }
    end
  end

  test "io ratio widget skips its PriceCatalog.models load on a cache hit" do
    # The widget's fallback (PriceCatalog.models — the expensive
    # AiModel.listed.includes(...) load) must run INSIDE the cache block, so a
    # warm render skips it. The how-pricing-works action also loads the catalog
    # once via PriceCatalog.cheapest, so a cold render loads it more times than
    # a warm one: the difference is the widget's now-cached load.
    with_fragment_caching do
      counting_price_catalog_models do |count|
        get how_pricing_works_url   # cold: action + widget both load .models
        cold = count.call
        get how_pricing_works_url   # warm: widget served from cache
        warm = count.call - cold

        assert_operator warm, :<, cold,
          "a warm widget render must load PriceCatalog.models fewer times than a cold one"
      end
    end
  end
end
