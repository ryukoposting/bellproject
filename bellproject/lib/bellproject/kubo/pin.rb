module Kubo
  class Pin
    attr_accessor :cid
    attr_accessor :type
    def initialize(cid, type)
      if type.is_a? Symbol
        @type = type
      else
        @type = type.to_s.downcase.to_sym
      end
      @cid = cid.to_s
    end
  end
end
