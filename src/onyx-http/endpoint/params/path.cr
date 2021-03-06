require "http-params-serializable"
require "../../error"

module Onyx::HTTP::Endpoint
  # Define path params which are usually extracted from the request URL by `Onyx::HTTP::Router`.
  # Serialization is powered by [`HTTP::Params::Serializable`](https://github.com/vladfaust/http-params-serializable).
  #
  # NOTE: It does **not** extracts params from URL by itself, you need to have a router which
  # extracts path params into the `request.path_params` variable, for example,
  # `Onyx::HTTP::Router`; this code only *deserializes* them.
  #
  # Path params do not support neither nested nor array values.
  #
  # ```
  # struct GetUser
  #   include Onyx::HTTP::Endpoint
  #
  #   params do
  #     path do
  #       type id : Int32
  #     end
  #   end
  #
  #   def call
  #     pp! params.path.id
  #   end
  # end
  # ```
  #
  # ```shell
  # > curl http://localhost:5000/users/1
  # params.path.id => 1
  # ```
  macro path(&block)
    class PathParamsError < Onyx::HTTP::Error(400)
      def initialize(message : String, @path : Array(String))
        super(message)
      end

      def payload
        {path: @path}
      end
    end

    struct PathParams
      include ::HTTP::Params::Serializable

      {% verbatim do %}
        macro type(argument, **options, &block)
          {% if block %}
            {% raise "Path params do not support nesting" %}
          {% elsif argument.is_a?(TypeDeclaration) %}
            {% unless options.empty? %}
              @[::HTTP::Param({{**options}})]
            {% end %}

            getter {{argument}}
          {% else %}
            {% raise "BUG: Unhandled argument type #{argument.class_name}" %}
          {% end %}
        end
      {% end %}

      {{yield.id}}
    end

    @path = uninitialized PathParams
    getter path

    def initialize(request : ::HTTP::Request)
      previous_def

      @path = uninitialized PathParams

      begin
        @path = PathParams.from_query(request.path_params.join('&'){ |(k, v)| "#{k}=#{v}" })
      rescue ex : ::HTTP::Params::Serializable::Error
        raise PathParamsError.new("Path p" + ex.message.not_nil![1..-1], ex.path)
      end
    end
  end
end
