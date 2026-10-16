# frozen_string_literal: true

module RubyLLM
  # A CachedContent is a provider-side prompt cache resource. Create one
  # with ::create from a long, stable prompt prefix, then attach it to a
  # chat so later requests read the cached tokens instead of resending
  # them. This lifecycle requires a provider with managed cache resources;
  # automatic prompt caching is configured with Chat#with_caching.
  #
  #   cache = RubyLLM.cache(big_document, model: 'gemini-3.7-flash', ttl: 3600)
  #   chat = RubyLLM.chat(model: 'gemini-3.7-flash').with_caching(id: cache)
  #   chat.ask "What does the document conclude?"
  #   cache.delete
  #
  # Cache ids are provider-owned. Persist #provider alongside #id and
  # pass it back when finding the cache later.
  class CachedContent
    include Support::Inspectable

    # The provider's id for the cache, such as
    # <tt>"cachedContents/abc123"</tt>.
    attr_reader :id

    # The id of the model the cache was created for, as a String.
    attr_reader :model

    # The slug of the provider that stores the cache.
    attr_reader :provider

    # The Time the provider stored the cache.
    attr_reader :created_at

    # The Time the provider will delete the cache.
    attr_reader :expires_at

    # The number of tokens stored in the cache.
    attr_reader :tokens

    # The raw provider response data for the cache, as a Hash.
    attr_reader :raw

    def metadata # :nodoc:
      RubyLLM.deprecator.deprecate('CachedContent#metadata', replacement: 'CachedContent#raw', removal: '3.0')
      raw
    end

    def name # :nodoc:
      RubyLLM.deprecator.deprecate('CachedContent#name', replacement: 'CachedContent#id', removal: '3.0')
      id
    end

    def initialize(id:, **attributes) # :nodoc:
      @id = id
      @model = attributes[:model]
      @provider_instance = attributes[:provider_instance]
      @provider = attributes[:provider] || @provider_instance&.slug
      @created_at = attributes[:created_at]
      @expires_at = attributes[:expires_at]
      @tokens = attributes[:tokens]
      @raw = attributes[:raw] || {}
    end

    # Deletes the cache resource from the provider. Returns +self+.
    def delete
      @provider_instance.delete_cache(id)
      self
    end

    # Extends the cache's lifetime to +ttl:+ seconds from now, given as an
    # Integer or a provider duration string such as <tt>"600s"</tt>.
    # Updates #expires_at and returns +self+.
    #
    #   cache.renew(ttl: 3600)
    #
    def renew(ttl:)
      refreshed = @provider_instance.extend_cache(id, ttl: ttl)
      @expires_at = refreshed.expires_at
      @raw = refreshed.raw
      self
    end

    # Creates a provider-side prompt cache from +content+ and returns a
    # CachedContent. Also available as RubyLLM.cache.
    #
    #   RubyLLM::CachedContent.create(big_document, model: 'gemini-3.7-flash')
    #
    # +content+ is the text to cache. +model:+ selects the model the cache
    # is created for and is required. +provider:+ forces a specific
    # provider. +context:+ supplies a Context whose configuration replaces
    # the global one. +ttl:+ sets the cache lifetime in seconds (Integer) or
    # as a provider duration string such as <tt>"300s"</tt>.
    # +instructions:+ caches a system prompt alongside the content, and
    # +with:+ passes file attachments the way Chat#ask accepts them. The
    # content must exceed the model's minimum cacheable token count.
    def self.create(content, model:, provider: nil, context: nil, ttl: nil, instructions: nil, with: nil)
      config = context&.config || RubyLLM.config
      model_instance, provider_instance = Models.resolve(model, provider: provider, config: config)

      provider_instance.cache_content(content, model: model_instance, ttl:, instructions:, with:)
    end

    # Fetches an existing cache resource by +id+ and returns a
    # CachedContent. When +provider:+ is omitted, the provider of the
    # configured default model is used.
    #
    #   cache = RubyLLM::CachedContent.find("cachedContents/abc123", provider: :gemini)
    #
    def self.find(id, provider: nil, context: nil)
      config = context&.config || RubyLLM.config

      provider_instance = if provider
                            Provider.resolve!(provider).new(config)
                          else
                            Models.resolve(config.default_model, config:).last
                          end
      provider_instance.find_cache(id)
    end

    private

    def inspect_attributes # :nodoc:
      { id: id, model: model, provider: provider, expires_at: expires_at }
    end
  end
end
