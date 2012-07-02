require 'json'
require 'cgi'

class Factual
  class API
    VERSION = "1.2.1"
    API_V3_HOST = "api.v3.factual.com"
    DRIVER_VERSION_TAG = "factual-ruby-driver-v" + VERSION
    PARAM_ALIASES = { :search => :q, :sort_asc => :sort }

    def initialize(access_token, debug_mode = false, host = nil)
      @access_token = access_token
      @debug_mode = debug_mode
      @host = host || API_V3_HOST
    end

    def get(query, other_params = {})
      merged_params = query.params.merge(other_params)
      handle_request(query.action || :read, query.path, merged_params)
    end

    def post(request)
      response = make_request("http://" + @host + request.path, request.body, :post)
      payload = JSON.parse(response.body)
      handle_payload(payload)
    end

    def schema(query)
      handle_request(:schema, query.path, query.params)["view"]
    end

    def raw_read(path)
      payload = JSON.parse(make_request("http://#{@host}#{path}").body)
      handle_payload(payload)
    end

    def full_path(action, path, params)
      fp = "/#{path}"
      fp += "/#{action}" unless action == :read
      fp += "?#{query_string(params)}"
    end

    private

    def handle_request(action, path, params)
      url = "http://#{@host}" + full_path(action, path, params)

      payload = JSON.parse(make_request(url).body)

      if (path == :multi)
         payload.inject({}) do |res, item|
           name, p = item
           res[name] = handle_payload(p)
         end
      else
        handle_payload(payload)
      end
    end

    def handle_payload(payload)
      raise StandardError.new(payload.to_json) unless payload["status"] == "ok"
      payload["response"]
    end

    def make_request(url, body=nil, method=:get)
      start_time = Time.now

      headers = { "X-Factual-Lib" => DRIVER_VERSION_TAG }

      res = if (method == :get)
              @access_token.get(url, headers)
            elsif (method == :post)
              @access_token.post(url, body, headers)
            else
              raise StandardError.new("Unknown http method")
            end

      elapsed_time = (Time.now - start_time) * 1000
      debug(url, method, headers, body, res, elapsed_time) if @debug_mode

      res
    end

    def query_string(params)
      query_array = params.keys.inject([]) do |array, key|
        param_alias = PARAM_ALIASES[key.to_sym] || key.to_sym
        value = params[key].class == Hash ? params[key].to_json : params[key].to_s
        array << "#{param_alias}=#{CGI.escape(value)}"
      end

      query_array.join("&")
    end

    def debug(url, method, headers, body, res, elapsed_time)
      res_headers = res.to_hash.inject({}) do |h, kv|
        k, v = kv
        h[k] = v.join(',')
        h
      end

      puts "--- Driver version: #{DRIVER_VERSION_TAG}"
      puts "--- request debug ---"
      puts "req url: #{url}"
      puts "req method: #{method.upcase}"
      puts "req headers: #{JSON.pretty_generate(headers)}"
      puts "req body: #{body}" if body
      puts "---------------------"
      puts "--- response debug ---"
      puts "resp status code: #{res.code}"
      puts "resp status message: #{res.message}"
      puts "resp headers: #{JSON.pretty_generate(res_headers)}"
      puts "resp body: #{res.body}"
      puts "---------------------"
      puts "Elapsed time: #{elapsed_time} msecs"
      puts
    end
  end
end
