class Factual
  module Query
    class Resolve < Base
      def initialize(api, table, params = {})
        @table = table
        @path = "t/#{@table}/resolve"
        @action = :read
        super(api, params)
      end

      [:values].each do |param|
        define_method(param) do |*args|
          self.class.new(@api, @table, @params.merge(param => form_value(args)))
        end
      end
    end
  end
end
