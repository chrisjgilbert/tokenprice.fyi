module SourcesHelper
  # Source strings on price points are bare domains or domain/paths
  # ("anthropic.com/pricing", "docs.x.ai"). Render anything that looks like
  # one as an https:// link; anything else stays plain text.
  SOURCE_DOMAIN = %r{\A[a-z0-9][a-z0-9-]*(\.[a-z0-9-]+)+(/\S*)?\z}i

  def source_link(source)
    if source.match?(SOURCE_DOMAIN)
      link_to source, "https://#{source}", class: "sources-link", rel: "noopener"
    else
      content_tag(:span, source)
    end
  end
end
