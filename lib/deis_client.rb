require 'httparty'

module Deis
  class ApiWrapper
    include HTTParty
    format :json
    headers 'Accept' => 'application/json'

    API_PATH = '/v1'

    def initialize(deis_url)
      @base_uri = deis_url + API_PATH
      # self.class.base_uri (deis_url + API_PATH)
    end

    def get(path, options)
      self.class.get(@base_uri + path, options)
    end

    def post(path, options)
      self.class.post(@base_uri + path, options)
    end

    def delete(path, options)
      self.class.delete(@base_uri + path, options)
    end
  end

  class Client
    @@methods = {
      # method => HTTP-verb, path
      login: [:post, '/auth/login/'],
      apps: [:get, '/apps/'],
      create_app: [:post, '/apps/'],
      delete_app: [:delete, '/apps/%s/'],
      app: [:get, '/apps/%s/'],
      app_logs: [:get, '/apps/%s/logs/'],
      app_run: [:post, '/apps/%s/run/'],
      containers: [:get, '/apps/%s/containers/'],
      config: [:get, '/apps/%s/config'],
      domains: [:get, '/apps/%s/domains'],
      builds: [:get, '/apps/%s/builds'],
      create_build: [:post, '/apps/%s/builds'],
      releases: [:get, '/apps/%s/releases'],
      release: [:get, '/apps/%s/releases/%s'],
      rollback_release: [:post, '/apps/%s/releases/rollback']
    }

    def initialize(deis_url, username, password)
      @http = Deis::ApiWrapper.new deis_url
      @headers = {}
      @auth = {username: username, password: password}
    end

    def login
      response = @http.post('/auth/login/', {body: @auth})

      throw Exception unless response.code == 200

      @token = response['token']
      @headers['Authorization'] = "token #{@token}"
      response
    end

    def apps
      perform :apps
    end

    def create_app(id=nil)
      if id
        perform :create_app, {id: id}
      else
        perform :create_app
      end
    end

    def delete_app(id)
      perform :delete_app, {id: id}
    end

    def app(id)
      perform :app, {id: id}
    end

    def app_logs(id)
      perform :app_logs, {id: id}
    end

    protected

    # TODO: use own, meaningful exceptions expecially in this method
    def perform(method_sym, body={}, try_twice=true)
      login unless @token

      verb, path = @@methods[method_sym]
      path = path % body[:id] if path.include?('%s')

      options = {
        headers: @headers,
        body: body
      }
      response = @http.public_send verb, path, options

      case response.code
      when 200...300
        response.parsed_response
      when 401    # authentification required
        throw Exception unless try_twice
        login
        perform method_sym, options, false
      when 404
        nil   # or better an exception?
      else
        throw Exception
      end
    end
  end
end
