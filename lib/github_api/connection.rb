# encoding: utf-8

require 'faraday'
require 'github_api/response'
require 'github_api/response/mashify'
require 'github_api/response/jsonize'
require 'github_api/response/raise_error'
require 'github_api/response/header'
require 'github_api/request/oauth2'
require 'github_api/request/basic_auth'
require 'github_api/request/jsonize'

module Github

  # Specifies Http connection options
  module Connection
    extend self
    include Github::Constants

    ALLOWED_OPTIONS = [
      :headers,
      :url,
      :params,
      :request,
      :ssl
    ].freeze

    def default_options(options = {})
      accept = options[:headers] && options[:headers][:accept]
      {
        headers: {
          ACCEPT         =>  accept || 'application/vnd.github.v3+json,' \
                            'application/vnd.github.beta+json;q=0.5,' \
                            'application/json;q=0.1',
          ACCEPT_CHARSET => 'utf-8',
          USER_AGENT     => user_agent
        },
        ssl: ssl,
        url: options.fetch(:endpoint) { Github.endpoint }
      }
    end

    # Default middleware stack that uses default adapter as specified at
    # configuration stage.
    #
    def default_middleware(options = {})
      proc do |builder|
        builder.use Github::Request::Jsonize
        builder.use Faraday::Request::Multipart
        builder.use Faraday::Request::UrlEncoded
        builder.use Github::Request::OAuth2, oauth_token if oauth_token?
        builder.use Github::Request::BasicAuth, authentication if basic_authed?

        builder.use Faraday::Response::Logger if ENV['DEBUG']
        unless options[:raw]
          builder.use Github::Response::Mashify
          builder.use Github::Response::Jsonize
        end
        builder.use Github::Response::RaiseError
        builder.adapter adapter
      end
    end

    @connection = nil

    @stack = nil

    def clear_cache
      @connection = nil
    end

    def caching?
      !@connection.nil?
    end

    # Exposes middleware builder to facilitate custom stacks and easy
    # addition of new extensions such as cache adapter.
    #
    def stack(options = {}, &block)
      @stack ||= begin
        builder_class = defined?(Faraday::RackBuilder) ? Faraday::RackBuilder : Faraday::Builder

        if block_given?
          builder_class.new(&block)
        else
          builder_class.new(&default_middleware(options))
        end
      end
    end

    # Creates http connection
    #
    # Returns a Fraday::Connection object
    def connection(options = {})
      connection_options = default_options(options)
      clear_cache unless options.empty?
      connection_options.merge!(builder: stack(options))
      if ENV['DEBUG']
        p "Connection options : \n"
        pp connection_options
      end
      @connection ||= Faraday.new(connection_options)
    end

  end # Connection
end # Github
